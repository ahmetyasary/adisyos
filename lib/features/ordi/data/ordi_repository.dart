import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:orderix/features/ordi/data/ordi_actions.dart';
import 'package:orderix/features/ordi/data/ordi_local_brain.dart';
import 'package:orderix/features/ordi/data/ordi_snapshot.dart';
import 'package:orderix/features/ordi/domain/ordi_message.dart';

class OrdiAnswer {
  const OrdiAnswer(this.text, this.source, {this.actions = const []});

  final String text;
  final OrdiSource source;
  final List<OrdiToolCall> actions;
}

/// Data layer for Ordi: talks to the `ordi` edge function, degrades to the
/// offline brain, and persists the transcript in `ordi_chats`.
class OrdiRepository {
  OrdiRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _table = 'ordi_chats';
  static const _functionName = 'ordi';
  static const _timeout = Duration(seconds: 25);

  /// How many prior messages are replayed to the model for follow-up context.
  static const _historyWindow = 8;

  String? get _tenantId => _db.auth.currentUser?.id;

  // ── Ask ────────────────────────────────────────────────────────────────

  /// Answers [question]. Never throws: a transport failure becomes an offline
  /// answer, and an unanswerable offline question becomes an
  /// [OrdiSource.failure] message the UI renders as a soft warning.
  Future<OrdiAnswer> ask(String question, List<OrdiMessage> history) async {
    final snapshot = OrdiSnapshot.build();
    final recent = history.length <= _historyWindow
        ? history
        : history.sublist(history.length - _historyWindow);

    try {
      final res = await _db.functions
          .invoke(
            _functionName,
            body: {
              'question': question,
              'context': snapshot,
              'history': [
                for (final m in recent)
                  {'role': m.isUser ? 'user' : 'assistant', 'text': m.text},
              ],
            },
          )
          .timeout(_timeout);

      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      final answer = (data?['answer'] as String?)?.trim() ?? '';
      final actions = <OrdiToolCall>[
        for (final raw in (data?['actions'] as List? ?? const []))
          if (OrdiToolCall.fromJson(raw) != null) OrdiToolCall.fromJson(raw)!,
      ];
      if (answer.isNotEmpty || actions.isNotEmpty) {
        return OrdiAnswer(answer, OrdiSource.gemini, actions: actions);
      }
      return _offline(question, snapshot, reason: 'empty_response');
    } on FunctionException catch (e) {
      final code = _errorCode(e.details);
      if (code == 'forbidden') {
        return const OrdiAnswer(
          'Ordi yalnızca yönetici hesabıyla kullanılabiliyor. '
          'Personel oturumundan çıkıp yönetici olarak giriş yapmanız gerekiyor.',
          OrdiSource.failure,
        );
      }
      if (code == 'daily_limit') {
        return _offline(
          question,
          snapshot,
          reason: 'daily_limit',
          note: 'Günlük yapay zeka soru hakkınız doldu, '
              'bu cevabı uygulama içi hesaplamalarla hazırladım.',
        );
      }
      return _offline(question, snapshot, reason: 'function_${e.status}');
    } on TimeoutException {
      return _offline(question, snapshot, reason: 'timeout');
    } catch (e) {
      return _offline(question, snapshot, reason: e.runtimeType.toString());
    }
  }

  /// Falls back to [OrdiLocalBrain]. Returns an honest "can't answer" when no
  /// rule matches — inventing a number here would be worse than admitting it.
  OrdiAnswer _offline(
    String question,
    Map<String, dynamic> snapshot, {
    required String reason,
    String? note,
  }) {
    if (kDebugMode) debugPrint('[Ordi] offline fallback ($reason)');

    final parsed = OrdiIntentParser.parse(question, snapshot);
    if (parsed.isNotEmpty) {
      return OrdiAnswer(
        note ?? '',
        OrdiSource.local,
        actions: parsed,
      );
    }

    final local = OrdiLocalBrain(snapshot).answer(question);
    if (local != null) {
      return OrdiAnswer(
        note == null ? local : '$note\n\n$local',
        OrdiSource.local,
      );
    }

    return OrdiAnswer(
      'Bu soruyu şu an yanıtlayamıyorum — yapay zeka servisine '
      'ulaşamadım. Bağlantınızı kontrol edip tekrar deneyebilirsiniz.\n\n'
      'Bu arada şunları çevrimdışı da sorabilirsiniz: bugünkü ciro, '
      'açık masalar, kritik stok, en çok satanlar, ödeme dağılımı, '
      'vardiya durumu.',
      OrdiSource.failure,
    );
  }

  /// The edge function returns `{ "error": "<code>", ... }`; `FunctionException`
  /// surfaces that body (already decoded, or as a raw string) in `details`.
  String? _errorCode(Object? details) {
    if (details is Map) return details['error'] as String?;
    if (details is String) {
      for (final code in const [
        'forbidden',
        'daily_limit',
        'no_api_key',
        'gemini_unavailable',
      ]) {
        if (details.contains(code)) return code;
      }
    }
    return null;
  }

  // ── Transcript persistence ─────────────────────────────────────────────

  Future<List<OrdiMessage>> loadHistory({int limit = 60}) async {
    final tenantId = _tenantId;
    if (tenantId == null) return const [];
    try {
      final rows = await _db
          .from(_table)
          .select('role, content, source, created_at')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(limit);

      return [
        for (final row in rows.reversed)
          OrdiMessage(
            role: row['role'] == 'user' ? OrdiRole.user : OrdiRole.assistant,
            text: row['content'] as String? ?? '',
            source: OrdiMessage.sourceFromKey(row['source'] as String?),
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                    DateTime.now(),
          ),
      ];
    } catch (e) {
      if (kDebugMode) debugPrint('[Ordi] loadHistory error: $e');
      return const [];
    }
  }

  /// Fire-and-forget: a failed write must never block the conversation, since
  /// the message is already rendered from memory.
  Future<void> persist(OrdiMessage message) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    try {
      await _db.from(_table).insert({
        'tenant_id': tenantId,
        'role': message.isUser ? 'user' : 'assistant',
        'content': message.text,
        'source': message.sourceKey,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Ordi] persist error: $e');
    }
  }

  Future<void> clearHistory() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    try {
      await _db.from(_table).delete().eq('tenant_id', tenantId);
    } catch (e) {
      if (kDebugMode) debugPrint('[Ordi] clearHistory error: $e');
    }
  }
}
