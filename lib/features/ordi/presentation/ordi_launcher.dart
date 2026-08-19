import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import 'package:orderix/features/ordi/presentation/ordi_chat_sheet.dart';
import 'package:orderix/features/ordi/presentation/ordi_controller.dart';
import 'package:orderix/services/settings_service.dart';

// ── Apple-inspired design tokens (matched to the rest of the shell) ────────
const _orange = Color(0xFFFF9500);
const _card = Colors.white;
const _labelPrimary = Color(0xFF1C1C1E);
const _labelSecondary = Color(0xFF8E8E93);

const double _fabSize = 58;
const double _hitSize = _fabSize + 24;
const double _edgePad = 16;
const Duration _dockDuration = Duration(milliseconds: 420);

/// The floating Ordi button. Starts in the bottom-right corner. A long-press
/// drag follows the finger; releasing docks it to the nearest screen corner
/// and stores that corner for the account in Supabase (all devices share it).
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
  bool _dragging = false;
  bool _docking = false;
  Offset? _dragOrigin;
  Offset? _dragGlobalStart;

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
      if (mounted && !_dragging) _anim.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _nudgeWorker?.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _open({String? prompt}) {
    if (_dragging) return;
    final ordi = OrdiController.to;
    ordi.snoozeBubble();
    showOrdiChatSheet(context, initialPrompt: prompt);
  }

  Offset _clamp(Offset raw, Size size, EdgeInsets pad) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - _hitSize;
    final maxY = size.height - pad.bottom - _edgePad - _hitSize;
    return Offset(
      raw.dx.clamp(minX, maxX < minX ? minX : maxX),
      raw.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  /// Always docks to one of the four overlay corners.
  Offset _snapToCorner(Offset raw, Size size, EdgeInsets pad) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - _hitSize;
    final maxY = size.height - pad.bottom - _edgePad - _hitSize;
    final safeMaxX = maxX < minX ? minX : maxX;
    final safeMaxY = maxY < minY ? minY : maxY;
    final corners = <Offset>[
      Offset(minX, minY),
      Offset(safeMaxX, minY),
      Offset(minX, safeMaxY),
      Offset(safeMaxX, safeMaxY),
    ];
    var best = corners.first;
    var bestDist = (raw - best).distanceSquared;
    for (var i = 1; i < corners.length; i++) {
      final d = (raw - corners[i]).distanceSquared;
      if (d < bestDist) {
        best = corners[i];
        bestDist = d;
      }
    }
    return best;
  }

  Offset _offsetForCorner(String corner, Size size, EdgeInsets pad) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - _hitSize;
    final maxY = size.height - pad.bottom - _edgePad - _hitSize;
    final safeMaxX = maxX < minX ? minX : maxX;
    final safeMaxY = maxY < minY ? minY : maxY;
    switch (corner) {
      case 'tl':
        return Offset(minX, minY);
      case 'tr':
        return Offset(safeMaxX, minY);
      case 'bl':
        return Offset(minX, safeMaxY);
      default:
        return Offset(safeMaxX, safeMaxY);
    }
  }

  String _cornerOf(Offset snapped, Size size, EdgeInsets pad) {
    final target = _snapToCorner(snapped, size, pad);
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final atLeft = (target.dx - minX).abs() < 0.5;
    final atTop = (target.dy - minY).abs() < 0.5;
    if (atLeft && atTop) return 'tl';
    if (!atLeft && atTop) return 'tr';
    if (atLeft && !atTop) return 'bl';
    return 'br';
  }

  Offset _defaultOffset(Size size, EdgeInsets pad) {
    return _offsetForCorner('br', size, pad);
  }

  Offset _resolved(Size size, EdgeInsets pad) {
    if (_dragging) {
      final stored = OrdiController.to.launcherOffset;
      return _clamp(stored ?? _defaultOffset(size, pad), size, pad);
    }
    return _offsetForCorner(SettingsService.to.ordiCorner.value, size, pad);
  }

  void _commit(Offset next, Size size, EdgeInsets pad) {
    final target = _snapToCorner(next, size, pad);
    final from = _clamp(next, size, pad);
    _docking = (from - target).distanceSquared > 1;
    OrdiController.to.launcherOffset = target;
    SettingsService.to.setOrdiCorner(_cornerOf(target, size, pad));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ordi = OrdiController.to;

    return Positioned.fill(
      child: Obx(() {
        if (!ordi.isAvailable || ordi.isSheetOpen.value) {
          return const SizedBox.shrink();
        }

        final bubbleText = ordi.bubble.value;
        final pad = MediaQuery.paddingOf(context);
        // Rebuild when the saved corner changes (this device or another).
        SettingsService.to.ordiCorner.value;

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final pos = _resolved(size, pad);

            return _PassThrough(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                AnimatedPositioned(
                  duration: _dragging ? Duration.zero : _dockDuration,
                  curve: Curves.easeOutCubic,
                  left: pos.dx,
                  top: pos.dy,
                  width: _hitSize,
                  height: _hitSize,
                  onEnd: () {
                    if (!mounted || !_docking) return;
                    setState(() => _docking = false);
                  },
                  child: _OrdiButton(
                    anim: _anim,
                    scale: _scale,
                    tilt: _tilt,
                    ring: _ring,
                    dragging: _dragging,
                    onTap: () => _open(),
                    onLongPressStart: (details) {
                      _dragging = true;
                      _docking = false;
                      _dragOrigin = pos;
                      _dragGlobalStart = details.globalPosition;
                      ordi.snoozeBubble();
                      setState(() {});
                    },
                    onLongPressMoveUpdate: (details) {
                      final start = _dragGlobalStart;
                      final origin = _dragOrigin;
                      if (start == null || origin == null) return;
                      final delta = details.globalPosition - start;
                      OrdiController.to.launcherOffset =
                          _clamp(origin + delta, size, pad);
                      setState(() {});
                    },
                    onLongPressEnd: (_) {
                      final released =
                          OrdiController.to.launcherOffset ?? pos;
                      _dragging = false;
                      _dragOrigin = null;
                      _dragGlobalStart = null;
                      _commit(released, size, pad);
                    },
                  ),
                ),
                if (!_dragging && !_docking && bubbleText.isNotEmpty)
                  Positioned(
                    left: (pos.dx + _hitSize / 2 - 130).clamp(
                      _edgePad,
                      size.width - _edgePad - 260,
                    ),
                    bottom: size.height - pos.dy + 6,
                    width: 260,
                    child: _SuggestionBubble(
                      key: ValueKey(bubbleText),
                      text: bubbleText,
                      onTap: () => _open(prompt: bubbleText),
                      onDismiss: ordi.snoozeBubble,
                    ),
                  ),
              ],
            ),
            );
          },
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
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.dragging,
  });

  final Animation<double> anim;
  final Animation<double> scale;
  final Animation<double> tilt;
  final Animation<double> ring;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ordi yapay zeka asistanı',
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onLongPressStart,
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: onLongPressEnd,
        onLongPressCancel: () => onLongPressEnd(
          const LongPressEndDetails(),
        ),
        child: SizedBox(
          width: _hitSize,
          height: _hitSize,
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, child) {
              final t = ring.value;
              final dragScale = dragging ? 1.08 : 1.0;
              return Transform.scale(
                scale: dragScale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
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
                ),
              );
            },
            child: const _OrdiBadge(),
          ),
        ),
      ),
    );
  }
}

class _OrdiBadge extends StatelessWidget {
  const _OrdiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      bottomRight: Radius.circular(18),
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

/// Lets taps fall through empty overlay space to the app underneath.
class _PassThrough extends SingleChildRenderObjectWidget {
  const _PassThrough({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPassThrough();
}

class _RenderPassThrough extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }
}
