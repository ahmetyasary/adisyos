import 'dart:async';
import 'dart:ui' show Offset;

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/features/ordi/data/ordi_actions.dart';
import 'package:orderix/features/ordi/data/ordi_local_brain.dart';
import 'package:orderix/features/ordi/data/ordi_repository.dart';
import 'package:orderix/features/ordi/data/ordi_snapshot.dart';
import 'package:orderix/features/ordi/domain/ordi_message.dart';
import 'package:orderix/features/ordi/presentation/ordi_voice_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/table_service.dart';

/// State and orchestration for the Ordi assistant.
///
/// Registered once in `main()` and read by both the floating launcher and the
/// chat sheet, so the transcript survives closing and reopening the sheet.
class OrdiController extends GetxController {
  OrdiController({OrdiRepository? repository})
      : _repo = repository ?? OrdiRepository();

  static OrdiController get to => Get.find();

  final OrdiRepository _repo;

  /// How often the launcher nudges the user (animation + suggestion bubble).
  static const nudgeInterval = Duration(seconds: 5);

  /// How long each suggestion bubble stays on screen within a cycle.
  static const bubbleVisibleFor = Duration(seconds: 4);

  /// Dismissing a bubble silences suggestions for this long. The launcher keeps
  /// animating — only the text bubble is snoozed.
  static const _snoozeFor = Duration(minutes: 10);

  static const maxQuestionLength = 500;

  // ── Reactive state ─────────────────────────────────────────────────────

  final RxList<OrdiMessage> messages = <OrdiMessage>[].obs;
  final RxBool isThinking = false.obs;
  final RxBool isSheetOpen = false.obs;

  /// Drives the launcher's attention animation; increments on every nudge tick.
  final RxInt nudgeTick = 0.obs;

  /// Currently displayed suggestion, or empty when the bubble is hidden.
  final RxString bubble = ''.obs;

  Timer? _nudgeTimer;
  Timer? _bubbleHideTimer;
  DateTime? _snoozedUntil;
  bool _historyLoaded = false;
  List<OrdiToolCall>? _pendingChanges;

  /// Top-left of the Ordi FAB in the overlay, or null to use the layout default.
  Offset? launcherOffset;

  List<String> _suggestions = const [];
  int _suggestionIndex = 0;

  /// Ordi reads revenue and staff data, so it is admin-only — matching the
  /// server-side check in the `ordi` edge function.
  bool get isAvailable =>
      AuthController.to.isAuthenticated && AuthController.to.isAdmin;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    // The nudge timer is owned by the controller, not by the launcher widget.
    // The shell swaps between its phone and tablet layouts when the window is
    // resized, and a widget-owned timer would be cancelled by the outgoing
    // layout's `dispose` *after* the incoming one started it — silencing Ordi
    // for the rest of the session. Ticks are near-free when nobody is
    // listening, since [_nudge] bails out unless a launcher can act on it.
    _nudgeTimer = Timer.periodic(nudgeInterval, (_) => _nudge());

    // A transcript belongs to one tenant. Dropping it when the account changes
    // means the next user can never see the previous one's cached messages.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.signedIn) {
        resetForNewSession();
      }
    });
  }

  @override
  void onClose() {
    _nudgeTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.onClose();
  }

  void _nudge() {
    if (!isAvailable || isSheetOpen.value) {
      bubble.value = '';
      return;
    }

    nudgeTick.value++;

    final snoozed =
        _snoozedUntil != null && DateTime.now().isBefore(_snoozedUntil!);
    if (snoozed) return;

    bubble.value = _nextSuggestion();
    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(bubbleVisibleFor, () => bubble.value = '');
  }

  /// Hides the current bubble and silences further ones for [_snoozeFor].
  void snoozeBubble() {
    _snoozedUntil = DateTime.now().add(_snoozeFor);
    _bubbleHideTimer?.cancel();
    bubble.value = '';
  }

  // ── Suggestions ────────────────────────────────────────────────────────

  String _nextSuggestion() {
    if (_suggestionIndex >= _suggestions.length) {
      _suggestions = _buildSuggestions();
      _suggestionIndex = 0;
    }
    return _suggestions[_suggestionIndex++];
  }

  /// Suggestions double as prompts: tapping the bubble sends the same text.
  /// Deliberately reads only the cheap reactive bits (not the full snapshot) —
  /// this runs on a 5-second timer.
  List<String> _buildSuggestions() {
    final out = <String>[];

    if (Get.isRegistered<InventoryService>()) {
      final critical = InventoryService.to.lowStockItems.length;
      if (critical > 0) {
        out.add('$critical ürünün stoğu kritik, hangileri?');
      }
    }

    if (Get.isRegistered<TableService>()) {
      final occupied =
          TableService.to.tables.where((t) => t['isOccupied'] == true).length;
      if (occupied > 0) {
        out.add('$occupied masa açık, toplam tutar ne kadar?');
      }
    }

    out.addAll(const [
      'Bugünkü ciro ne kadar?',
      'Dünle bugünü karşılaştırır mısın?',
      'Bu ayın en çok satan ürünleri neler?',
      'Hangi saatlerde daha yoğunuz?',
      'Ortalama adisyon tutarım ne?',
      'Ciromu artırmak için ne önerirsin?',
      'Bu hafta nasıl gidiyor?',
      'Nakit mi kart mı daha çok kullanılıyor?',
    ]);

    return out;
  }

  /// Chips shown inside the sheet when the transcript is empty.
  List<String> get quickPrompts => [
        'Bugünün özeti',
        'Açık masalar',
        'Kritik stoklar',
        'En çok satanlar',
        'Bu ay ciro',
        'Vardiya durumu',
      ];

  // ── Conversation ───────────────────────────────────────────────────────

  /// Loads the persisted transcript once per session and greets a new user.
  Future<void> ensureHistory() async {
    if (_historyLoaded || !isAvailable) return;
    _historyLoaded = true;

    final history = await _repo.loadHistory();
    if (history.isNotEmpty) {
      messages.assignAll(history);
      return;
    }

    messages.add(OrdiMessage.assistant(
      'Merhaba, ben Ordi. Sorularınızı yanıtlarım; eklemeleri hemen yaparım, '
      'değişikliklerde onay isterim. Silme yapmam.\n\n'
      '${OrdiLocalBrain(OrdiSnapshot.build()).summary()}',
      source: OrdiSource.local,
    ));
  }

  Future<void> send(String rawText, {bool speakReply = false}) async {
    final text = rawText.trim();
    if (text.isEmpty || isThinking.value || !isAvailable) return;

    final question = text.length > maxQuestionLength
        ? text.substring(0, maxQuestionLength)
        : text;

    if (speakReply && Get.isRegistered<OrdiVoiceService>()) {
      await OrdiVoiceService.to.stopSpeaking();
    }

    final userMessage = OrdiMessage.user(question);
    messages.add(userMessage);
    isThinking.value = true;

    // Persisted in the background — the UI already shows the message.
    _repo.persist(userMessage);

    String spokenBody = '';
    try {
      if (_pendingChanges != null && ordiIsAffirmative(question)) {
        final result = await OrdiActionRunner.run(_pendingChanges!);
        _pendingChanges = null;
        spokenBody =
            result.trim().isEmpty ? 'Onaylanan işlem uygulandı.' : result.trim();
        final reply = OrdiMessage.assistant(
          spokenBody,
          source: OrdiSource.local,
        );
        messages.add(reply);
        _repo.persist(reply);
      } else if (_pendingChanges != null && ordiIsNegative(question)) {
        _pendingChanges = null;
        spokenBody = 'İşlemi iptal ettim. Başka bir şey yapmamı ister misiniz?';
        final reply = OrdiMessage.assistant(
          spokenBody,
          source: OrdiSource.local,
        );
        messages.add(reply);
        _repo.persist(reply);
      } else {
        _pendingChanges = null;

        // Exclude the just-added question; it is sent separately.
        final priorTurns = messages.sublist(0, messages.length - 1);
        final answer = await _repo.ask(question, priorTurns);
        var body = OrdiActionRunner.stripLeakedToolText(answer.text.trim());
        final split = OrdiActionRunner.split(answer.actions);
        if (split.adds.isNotEmpty) {
          final result = await OrdiActionRunner.run(split.adds);
          body = [
            if (body.isNotEmpty) body,
            if (result.trim().isNotEmpty) result.trim(),
          ].join('\n\n');
        }
        if (split.blocked.isNotEmpty) {
          body = [
            if (body.isNotEmpty) body,
            'Silme işlemi yapamam. Desteklenmeyen istekler atlandı.',
          ].join('\n\n');
        }
        if (split.changes.isNotEmpty) {
          _pendingChanges = split.changes;
          body = [
            if (body.isNotEmpty) body,
            OrdiActionRunner.confirmPrompt(split.changes),
          ].join('\n\n');
        }
        if (body.isEmpty) {
          body = 'İsteğinizi aldım ama uygulanacak bir işlem çıkmadı.';
        }

        spokenBody = body;
        final reply = OrdiMessage.assistant(body, source: answer.source);
        messages.add(reply);
        _repo.persist(reply);
      }
    } finally {
      isThinking.value = false;
    }

    if (speakReply &&
        spokenBody.isNotEmpty &&
        Get.isRegistered<OrdiVoiceService>()) {
      await OrdiVoiceService.to.speak(spokenBody);
    }
  }

  Future<void> clearConversation() async {
    messages.clear();
    _historyLoaded = false;
    _pendingChanges = null;
    await _repo.clearHistory();
    await ensureHistory();
  }

  /// Called when the account changes so the next open reloads the right
  /// tenant's transcript.
  void resetForNewSession() {
    messages.clear();
    _historyLoaded = false;
    _pendingChanges = null;
    _snoozedUntil = null;
    _suggestions = const [];
    _suggestionIndex = 0;
    bubble.value = '';
    launcherOffset = null;
  }
}
