import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:orderix/features/ordi/domain/ordi_message.dart';
import 'package:orderix/features/ordi/presentation/ordi_controller.dart';
import 'package:orderix/features/ordi/presentation/ordi_voice_service.dart';
import 'package:orderix/utils/app_haptics.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/brand_assets.dart';

// ── Apple-inspired design tokens (matched to the rest of the shell) ────────
Color get _bg => AppColors.scaffold;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
const _labelPrimary = Color(0xFF1C1C1E);
const _labelSecondary = Color(0xFF8E8E93);
const _separator = Color(0xFFE5E5EA);
const _amber = Color(0xFFFF9F0A);

/// Opens the Ordi conversation. [initialPrompt] is sent as soon as the sheet
/// settles, which is how tapping a suggestion bubble asks its question.
Future<void> showOrdiChatSheet(
  BuildContext context, {
  String? initialPrompt,
}) async {
  final ordi = OrdiController.to;
  if (!ordi.isAvailable) return;

  ordi.isSheetOpen.value = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OrdiChatSheet(initialPrompt: initialPrompt),
    );
  } finally {
    ordi.isSheetOpen.value = false;
  }
}

class _OrdiChatSheet extends StatefulWidget {
  const _OrdiChatSheet({this.initialPrompt});

  final String? initialPrompt;

  @override
  State<_OrdiChatSheet> createState() => _OrdiChatSheetState();
}

class _OrdiChatSheetState extends State<_OrdiChatSheet> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  /// True from mic tap until user confirms with X (even if STT pauses).
  bool _voiceSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ordi = OrdiController.to;
      await ordi.ensureHistory();
      final prompt = widget.initialPrompt?.trim();
      if (prompt != null && prompt.isNotEmpty) await ordi.send(prompt);
    });
  }

  @override
  void dispose() {
    _voiceSession = false;
    if (Get.isRegistered<OrdiVoiceService>()) {
      final voice = OrdiVoiceService.to;
      voice.cancelListening();
      voice.stopSpeaking();
    }
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final value = (text ?? _input.text).trim();
    if (value.isEmpty) return;
    _input.clear();
    if (Get.isRegistered<OrdiVoiceService>()) {
      OrdiVoiceService.to.stopSpeaking();
    }
    OrdiController.to.send(value);
  }

  Future<void> _onMicTap() async {
    if (!Get.isRegistered<OrdiVoiceService>()) return;
    if (OrdiController.to.isThinking.value) return;

    // Second tap (X): confirm transcript and send.
    if (_voiceSession) {
      await _confirmVoice();
      return;
    }

    AppHaptics.selection();
    setState(() => _voiceSession = true);
    final voice = OrdiVoiceService.to;
    final ok = await voice.startListening(
      onPartial: (partial) {
        if (!mounted || !_voiceSession) return;
        _input.value = TextEditingValue(
          text: partial,
          selection: TextSelection.collapsed(offset: partial.length),
        );
      },
      onLocaleMissing: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cihazda Türkçe konuşma tanıma yok. '
              'Ayarlar → Genel → Klavye → Dikte / Dil’den Türkçe ekleyin.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      },
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _voiceSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mikrofon veya konuşma tanıma izni gerekli.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmVoice() async {
    if (!_voiceSession) return;
    AppHaptics.selection();
    setState(() => _voiceSession = false);
    if (!Get.isRegistered<OrdiVoiceService>()) return;

    final fromStt = await OrdiVoiceService.to.stopListening();
    final text = (fromStt.isNotEmpty ? fromStt : _input.text).trim();
    if (!mounted) return;
    if (text.isEmpty) {
      _input.clear();
      return;
    }
    _input.clear();
    await OrdiController.to.send(text, speakReply: true);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sohbeti Temizle',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ordi ile olan tüm yazışmanız kalıcı olarak silinecek.',
          style: TextStyle(fontSize: 13, color: _labelSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Vazgeç',
                style: TextStyle(color: _labelSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sil',
                style: TextStyle(
                    color: Color(0xFFFF3B30), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await OrdiController.to.clearConversation();
  }

  @override
  Widget build(BuildContext context) {
    final ordi = OrdiController.to;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: maxHeight,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _Header(onClear: _confirmClear),
            Expanded(
              child: Obx(() {
                final messages = ordi.messages;
                final thinking = ordi.isThinking.value;

                if (messages.isEmpty && !thinking) {
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _orange),
                    ),
                  );
                }

                // Reversed list keeps the newest message pinned to the bottom
                // without any manual scroll-controller choreography.
                final items = messages.reversed.toList();

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: items.length + (thinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (thinking && index == 0) return const _TypingBubble();
                    final message = items[index - (thinking ? 1 : 0)];
                    return _MessageBubble(message: message);
                  },
                );
              }),
            ),
            Obx(() {
              final showChips = ordi.messages.length <= 1;
              return showChips
                  ? _QuickPrompts(
                      prompts: ordi.quickPrompts,
                      onTap: _submit,
                    )
                  : const SizedBox.shrink();
            }),
            _Composer(
              controller: _input,
              focusNode: _inputFocus,
              voiceSession: _voiceSession,
              onSubmit: _submit,
              onMicTap: _onMicTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: _separator, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: _separator,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _OrdiAvatar(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _labelPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'İşletme verilerinizi bilen asistan',
                      style: TextStyle(fontSize: 12, color: _labelSecondary),
                    ),
                  ],
                ),
              ),
              _CircleAction(
                icon: CupertinoIcons.trash,
                onTap: onClear,
                tooltip: 'Sohbeti temizle',
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: CupertinoIcons.xmark,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Kapat',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdiAvatar extends StatelessWidget {
  const _OrdiAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _card,
        border: Border.all(color: _orange.withValues(alpha: 0.3), width: 1.2),
      ),
      child: BrandMark(size: size * 0.68),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _bg,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: _labelSecondary),
          ),
        ),
      ),
    );
  }
}

// ── Messages ──────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final OrdiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isFailure = message.isFailure;

    final bubbleColor = isUser
        ? _orange
        : isFailure
            ? _amber.withValues(alpha: 0.10)
            : _card;
    final textColor = isUser ? Colors.white : _labelPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _OrdiAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                border: isFailure
                    ? Border.all(color: _amber.withValues(alpha: 0.35))
                    : null,
                boxShadow: isUser
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormattedText(text: message.text, color: textColor),
                  if (message.source == OrdiSource.local)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: _SourceChip(
                        icon: CupertinoIcons.bolt_horizontal,
                        label: 'çevrimdışı hesaplama',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _labelSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _labelSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Renders Ordi's plain-text replies: `**bold**` becomes bold, and `-`/`*`
/// list markers are normalised to `•`. Deliberately not a markdown engine —
/// the system prompt asks for plain text, and this keeps the dependency count
/// at zero.
class _FormattedText extends StatelessWidget {
  const _FormattedText({required this.text, required this.color});

  final String text;
  final Color color;

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  static final _bulletPattern = RegExp(r'^\s*[-*]\s+', multiLine: true);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 14.5,
      height: 1.42,
      color: color,
      letterSpacing: -0.1,
    );
    final normalised = text.replaceAll(_bulletPattern, '• ');

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _boldPattern.allMatches(normalised)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: normalised.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      cursor = match.end;
    }
    if (cursor < normalised.length) {
      spans.add(TextSpan(text: normalised.substring(cursor)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const _OrdiAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i != 0) const SizedBox(width: 5),
                    Opacity(
                      // Each dot is a third of a cycle behind the previous one,
                      // which reads as a wave travelling left to right.
                      opacity: _dotOpacity((_anim.value + i / 3) % 1.0),
                      child: const _Dot(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _dotOpacity(double phase) =>
    0.28 + 0.72 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _orange),
      );
}

// ── Quick prompts ─────────────────────────────────────────────────────────

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.prompts, required this.onTap});

  final List<String> prompts;
  final void Function(String prompt) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return Material(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onTap(prompt),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _orange.withValues(alpha: 0.25)),
                ),
                child: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _orange,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Composer ──────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.voiceSession,
    required this.onSubmit,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool voiceSession;
  final VoidCallback onSubmit;
  final Future<void> Function() onMicTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _separator, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: voiceSession
                      ? _orange.withValues(alpha: 0.08)
                      : _bg,
                  borderRadius: BorderRadius.circular(22),
                  border: voiceSession
                      ? Border.all(
                          color: _orange.withValues(alpha: 0.35),
                        )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (voiceSession) ...[
                      const _ListeningDots(),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        maxLines: 4,
                        minLines: 1,
                        maxLength: OrdiController.maxQuestionLength,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => onSubmit(),
                        style: TextStyle(
                            fontSize: 15, color: _labelPrimary),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          hintText: voiceSession
                              ? 'Dinleniyor… bitince X’e dokunun'
                              : 'Ordi\'ye bir soru sorun…',
                          hintStyle: TextStyle(
                              fontSize: 15, color: _labelSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final busy = OrdiController.to.isThinking.value;
              final speaking = Get.isRegistered<OrdiVoiceService>() &&
                  OrdiVoiceService.to.isSpeaking.value;
              return _VoiceButton(
                active: voiceSession,
                busy: busy,
                speaking: speaking,
                onTap: busy
                    ? null
                    : () {
                        onMicTap();
                      },
              );
            }),
            const SizedBox(width: 8),
            Obx(() {
              final busy = OrdiController.to.isThinking.value;
              return Material(
                color: busy ? _separator : _orange,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: busy || voiceSession
                      ? null
                      : () {
                          AppHaptics.selection();
                          onSubmit();
                        },
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      CupertinoIcons.arrow_up,
                      size: 20,
                      color: busy || voiceSession
                          ? _labelSecondary
                          : Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Pulsing mic / confirm (X) control for the voice session.
class _VoiceButton extends StatefulWidget {
  const _VoiceButton({
    required this.active,
    required this.busy,
    required this.speaking,
    required this.onTap,
  });

  final bool active;
  final bool busy;
  final bool speaking;
  final VoidCallback? onTap;

  @override
  State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? const Color(0xFFFF3B30)
        : widget.speaking
            ? _amber
            : widget.busy
                ? _separator
                : _bg;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                return Container(
                  width: 44 + 16 * t,
                  height: 44 + 16 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF3B30)
                          .withValues(alpha: 0.45 * (1 - t)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  widget.active
                      ? CupertinoIcons.xmark
                      : CupertinoIcons.mic,
                  size: widget.active ? 18 : 20,
                  color: widget.active || widget.speaking
                      ? Colors.white
                      : widget.busy
                          ? _labelSecondary
                          : _labelPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningDots extends StatefulWidget {
  const _ListeningDots();

  @override
  State<_ListeningDots> createState() => _ListeningDotsState();
}

class _ListeningDotsState extends State<_ListeningDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i != 0) const SizedBox(width: 3),
            Opacity(
              opacity: _dotOpacity((_anim.value + i / 3) % 1.0),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
