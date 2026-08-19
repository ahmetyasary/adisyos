import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:orderix/features/ordi/presentation/ordi_chat_sheet.dart';
import 'package:orderix/features/ordi/presentation/ordi_controller.dart';

// ── Apple-inspired design tokens (matched to the rest of the shell) ────────
const _orange = Color(0xFFFF9500);
const _card = Colors.white;
const _labelPrimary = Color(0xFF1C1C1E);
const _labelSecondary = Color(0xFF8E8E93);

const double _fabSize = 58;

/// The floating Ordi button, pinned bottom-right over the shell content.
///
/// Every [OrdiController.nudgeInterval] tick it plays a short attention
/// animation (bounce + wiggle + expanding ring) and surfaces a contextual
/// suggestion bubble to its left. Tapping either opens the chat sheet; tapping
/// the bubble also sends its text as the first question.
class OrdiLauncher extends StatefulWidget {
  const OrdiLauncher({super.key});

  @override
  State<OrdiLauncher> createState() => _OrdiLauncherState();
}

class _OrdiLauncherState extends State<OrdiLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _tilt;
  late final Animation<double> _ring;

  Worker? _nudgeWorker;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_anim);

    // Small rocking motion, in radians. Keeps the logo readable at all frames.
    _tilt = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: -0.07), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));

    _ring = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0, 0.75, curve: Curves.easeOut),
    );

    _nudgeWorker = ever(OrdiController.to.nudgeTick, (_) {
      if (mounted) _anim.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _nudgeWorker?.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _open({String? prompt}) {
    final ordi = OrdiController.to;
    ordi.snoozeBubble();
    showOrdiChatSheet(context, initialPrompt: prompt);
  }

  @override
  Widget build(BuildContext context) {
    final ordi = OrdiController.to;

    // `Positioned` stays outside the `Obx` so it is always a direct structural
    // child of the host `Stack`.
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Obx(() {
        if (!ordi.isAvailable || ordi.isSheetOpen.value) {
          return const SizedBox.shrink();
        }

        final bubbleText = ordi.bubble.value;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.12, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: bubbleText.isEmpty
                    ? const SizedBox(key: ValueKey('empty'), height: 0)
                    : _SuggestionBubble(
                        key: ValueKey(bubbleText),
                        text: bubbleText,
                        onTap: () => _open(prompt: bubbleText),
                        onDismiss: ordi.snoozeBubble,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            _OrdiButton(
              anim: _anim,
              scale: _scale,
              tilt: _tilt,
              ring: _ring,
              onTap: _open,
            ),
          ],
        );
      }),
    );
  }
}

class _OrdiButton extends StatelessWidget {
  const _OrdiButton({
    required this.anim,
    required this.scale,
    required this.tilt,
    required this.ring,
    required this.onTap,
  });

  final Animation<double> anim;
  final Animation<double> scale;
  final Animation<double> tilt;
  final Animation<double> ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ordi yapay zeka asistanı',
      child: SizedBox(
        width: _fabSize + 24,
        height: _fabSize + 24,
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            final t = ring.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding halo that fades out — reads as "I have something
                // to tell you" without moving the button off its anchor.
                IgnorePointer(
                  child: Transform.scale(
                    scale: 1 + t * 0.6,
                    child: Opacity(
                      opacity: (1 - t) * 0.35,
                      child: Container(
                        width: _fabSize,
                        height: _fabSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _orange,
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: scale.value,
                  child: Transform.rotate(angle: tilt.value, child: child),
                ),
              ],
            );
          },
          child: _OrdiBadge(onTap: onTap),
        ),
      ),
    );
  }
}

class _OrdiBadge extends StatelessWidget {
  const _OrdiBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _fabSize,
        height: _fabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _card,
          border: Border.all(color: _orange.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _orange.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(9),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
                // The bundled logo is the brand "O"; if it ever goes missing
                // the button must still render something tappable.
                errorBuilder: (_, __, ___) => const Text(
                  'O',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _orange,
                  ),
                ),
              ),
            ),
            // "AI" spark marker so the button reads as an assistant rather than
            // a shortcut back to the home screen.
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _card,
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  size: 12,
                  color: _orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The speech bubble that appears beside the launcher on each nudge.
class _SuggestionBubble extends StatelessWidget {
  const _SuggestionBubble({
    super.key,
    required this.text,
    required this.onTap,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const shape = BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      // Clipped corner points at the launcher, like a speech tail.
      bottomRight: Radius.circular(4),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        color: _card,
        elevation: 0,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: _orange.withValues(alpha: 0.22)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ordi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _orange,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: _labelPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 13,
                      color: _labelSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a shell body with the Ordi launcher floating above it. The launcher
/// hides itself when the session isn't allowed to use Ordi.
Widget withOrdiLauncher(Widget body) {
  return Stack(
    children: [
      Positioned.fill(child: body),
      const OrdiLauncher(),
    ],
  );
}
