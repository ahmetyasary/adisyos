import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import 'package:orderix/features/ordi/presentation/ordi_chat_sheet.dart';
import 'package:orderix/features/ordi/presentation/ordi_controller.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/utils/app_haptics.dart';

// ── Apple-inspired design tokens (matched to the rest of the shell) ────────
const _orange = Color(0xFFFF9500);
const _card = Colors.white;
const _labelPrimary = Color(0xFF1C1C1E);
const _labelSecondary = Color(0xFF8E8E93);

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
  Worker? _cornerWorker;
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

    // Another device (or Settings) changed the shared corner — drop any
    // leftover absolute offset so the FAB docks to the new corner.
    _cornerWorker = ever(SettingsService.to.ordiCorner, (_) {
      if (!mounted || _dragging) return;
      OrdiController.to.launcherOffset = null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nudgeWorker?.dispose();
    _cornerWorker?.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _open({String? prompt}) {
    if (_dragging) return;
    final ordi = OrdiController.to;
    ordi.snoozeBubble();
    showOrdiChatSheet(context, initialPrompt: prompt);
  }

  Offset _clamp(Offset raw, Size size, EdgeInsets pad, double hitSize) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - hitSize;
    final maxY = size.height - pad.bottom - _edgePad - hitSize;
    return Offset(
      raw.dx.clamp(minX, maxX < minX ? minX : maxX),
      raw.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  /// Always docks to one of the four overlay corners.
  Offset _snapToCorner(Offset raw, Size size, EdgeInsets pad, double hitSize) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - hitSize;
    final maxY = size.height - pad.bottom - _edgePad - hitSize;
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

  Offset _offsetForCorner(
      String corner, Size size, EdgeInsets pad, double hitSize) {
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final maxX = size.width - pad.right - _edgePad - hitSize;
    final maxY = size.height - pad.bottom - _edgePad - hitSize;
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

  String _cornerOf(
      Offset snapped, Size size, EdgeInsets pad, double hitSize) {
    final target = _snapToCorner(snapped, size, pad, hitSize);
    final minX = pad.left + _edgePad;
    final minY = pad.top + _edgePad;
    final atLeft = (target.dx - minX).abs() < 0.5;
    final atTop = (target.dy - minY).abs() < 0.5;
    if (atLeft && atTop) return 'tl';
    if (!atLeft && atTop) return 'tr';
    if (atLeft && !atTop) return 'bl';
    return 'br';
  }

  Offset _defaultOffset(Size size, EdgeInsets pad, double hitSize) {
    return _offsetForCorner('br', size, pad, hitSize);
  }

  Offset _resolved(Size size, EdgeInsets pad, double hitSize) {
    if (_dragging) {
      final stored = OrdiController.to.launcherOffset;
      return _clamp(
          stored ?? _defaultOffset(size, pad, hitSize), size, pad, hitSize);
    }
    return _offsetForCorner(
        SettingsService.to.ordiCorner.value, size, pad, hitSize);
  }

  void _commit(Offset next, Size size, EdgeInsets pad, double hitSize) {
    final target = _snapToCorner(next, size, pad, hitSize);
    final from = _clamp(next, size, pad, hitSize);
    final newCorner = _cornerOf(target, size, pad, hitSize);
    final oldCorner = SettingsService.to.ordiCorner.value;
    _docking = (from - target).distanceSquared > 1;
    // Prefer corner-based layout so other devices (and size changes) stay aligned.
    OrdiController.to.launcherOffset = null;
    SettingsService.to.setOrdiCorner(newCorner);
    // Snap / corner change feedback (respects Settings → Titreşim).
    if (newCorner != oldCorner || _docking) {
      AppHaptics.selection();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ordi = OrdiController.to;

    return Positioned.fill(
      child: Obx(() {
        if (!ordi.isAvailable ||
            ordi.isSheetOpen.value ||
            !SettingsService.to.ordiVisible.value) {
          return const SizedBox.shrink();
        }

        final bubbleText = ordi.bubble.value;
        final pad = MediaQuery.paddingOf(context);
        // Rebuild when corner / size changes (this device or another).
        final corner = SettingsService.to.ordiCorner.value;
        final sizeKey = SettingsService.to.ordiSize.value;
        final fabSize = SettingsService.to.ordiFabSize;
        final hitSize = SettingsService.to.ordiHitSize;
        // Top corners: show suggestion speech under the FAB so it stays on-screen.
        final bubbleBelow = corner == 'tl' || corner == 'tr';
        final bubbleW = _bubbleWidthFor(sizeKey);

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final pos = _resolved(size, pad, hitSize);
            final bubbleLeft = (pos.dx + hitSize / 2 - bubbleW / 2).clamp(
              _edgePad,
              size.width - _edgePad - bubbleW,
            );

            return _PassThrough(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                AnimatedPositioned(
                  duration: _dragging ? Duration.zero : _dockDuration,
                  curve: Curves.easeOutCubic,
                  left: pos.dx,
                  top: pos.dy,
                  width: hitSize,
                  height: hitSize,
                  onEnd: () {
                    if (!mounted || !_docking) return;
                    setState(() => _docking = false);
                  },
                  child: _OrdiButton(
                    fabSize: fabSize,
                    hitSize: hitSize,
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
                          _clamp(origin + delta, size, pad, hitSize);
                      setState(() {});
                    },
                    onLongPressEnd: (_) {
                      final released =
                          OrdiController.to.launcherOffset ?? pos;
                      _dragging = false;
                      _dragOrigin = null;
                      _dragGlobalStart = null;
                      _commit(released, size, pad, hitSize);
                    },
                  ),
                ),
                if (!_dragging && !_docking && bubbleText.isNotEmpty)
                  Positioned(
                    left: bubbleLeft,
                    top: bubbleBelow ? pos.dy + hitSize + 6 : null,
                    bottom: bubbleBelow ? null : size.height - pos.dy + 6,
                    width: bubbleW,
                    child: _SuggestionBubble(
                      key: ValueKey('$bubbleText-$sizeKey'),
                      text: bubbleText,
                      sizeKey: sizeKey,
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

double _bubbleWidthFor(String sizeKey) {
  switch (sizeKey) {
    case 'sm':
      return 210;
    case 'lg':
      return 300;
    default:
      return 260;
  }
}

class _OrdiButton extends StatelessWidget {
  const _OrdiButton({
    required this.fabSize,
    required this.hitSize,
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

  final double fabSize;
  final double hitSize;
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
          width: hitSize,
          height: hitSize,
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
                            width: fabSize,
                            height: fabSize,
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
            child: _OrdiBadge(fabSize: fabSize),
          ),
        ),
      ),
    );
  }
}

class _OrdiBadge extends StatelessWidget {
  const _OrdiBadge({required this.fabSize});

  final double fabSize;

  @override
  Widget build(BuildContext context) {
    final pad = fabSize * 0.155;
    final spark = (fabSize * 0.21).clamp(10.0, 16.0);
    final fallbackFont = fabSize * 0.45;
    return Container(
        width: fabSize,
        height: fabSize,
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
              padding: EdgeInsets.all(pad),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
                // The bundled logo is the brand "O"; if it ever goes missing
                // the button must still render something tappable.
                errorBuilder: (_, __, ___) => Text(
                  'O',
                  style: TextStyle(
                    fontSize: fallbackFont,
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
                child: Icon(
                  CupertinoIcons.sparkles,
                  size: spark,
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
    required this.sizeKey,
    required this.onTap,
    required this.onDismiss,
  });

  final String text;
  final String sizeKey;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (maxW, titleSize, bodySize, padH, padV, radius, iconSize) =
        switch (sizeKey) {
      'sm' => (210.0, 10.0, 11.0, 10.0, 8.0, 14.0, 11.0),
      'lg' => (300.0, 13.0, 15.0, 16.0, 12.0, 20.0, 15.0),
      _ => (260.0, 11.0, 13.0, 14.0, 10.0, 18.0, 13.0),
    };
    final shape = BorderRadius.circular(radius);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
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
            padding: EdgeInsets.fromLTRB(padH, padV, padH * 0.45, padV),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ordi',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: _orange,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: sizeKey == 'sm' ? 1 : 2),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: bodySize,
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
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: padH * 0.4, vertical: 4),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: iconSize,
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
