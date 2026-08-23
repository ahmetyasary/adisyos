import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/app_theme.dart';

enum ToastType { success, warning, error, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _key = GlobalKey<_ToastState>();
  static final _undoKey = GlobalKey<_UndoToastState>();

  static void success(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.success, duration: duration);

  static void warning(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.warning, duration: duration);

  static void error(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.error, duration: duration);

  static void info(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.info, duration: duration);

  /// Undo toast with a live countdown ring (default 6s) and action button.
  static void undo({
    required String message,
    required VoidCallback onUndo,
    String title = 'Ürün kaldırıldı',
    String actionLabel = 'Geri Al',
    Duration duration = const Duration(seconds: 6),
  }) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;

    var undone = false;

    _entry = OverlayEntry(
      builder: (_) => _UndoToast(
        key: _undoKey,
        title: title,
        message: message,
        actionLabel: actionLabel,
        duration: duration,
        onUndo: () {
          if (undone) return;
          undone = true;
          onUndo();
        },
        onDismissed: _remove,
      ),
    );
    overlay.insert(_entry!);

    _timer = Timer(duration, () {
      _undoKey.currentState?.animateOut();
    });
  }

  static void _show(
    String message, {
    String? title,
    required ToastType type,
    Duration? duration,
  }) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;

    final dur = duration ?? const Duration(seconds: 3);

    _entry = OverlayEntry(
      builder: (_) => _Toast(
        key: _key,
        title: title,
        message: message,
        type: type,
        onDismissed: _remove,
      ),
    );
    overlay.insert(_entry!);

    _timer = Timer(dur, () {
      _key.currentState?.animateOut();
    });
  }

  static void _remove() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    super.key,
    this.title,
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  final String? title;
  final String message;
  final ToastType type;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _ac,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ));
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));
    _ac.forward();
  }

  void animateOut() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _ac.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.type) {
      case ToastType.success:
        return AppTheme.successColor;
      case ToastType.warning:
        return AppTheme.warningColor;
      case ToastType.error:
        return AppTheme.errorColor;
      case ToastType.info:
        return AppTheme.infoColor;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return CupertinoIcons.checkmark_circle_fill;
      case ToastType.warning:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case ToastType.error:
        return CupertinoIcons.xmark_circle_fill;
      case ToastType.info:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTitle = widget.title != null && widget.title!.isNotEmpty;
    final maxW = mq.size.width > 600 ? 400.0 : mq.size.width - 40.0;

    return Positioned(
      top: mq.padding.top + 8,
      left: 0,
      right: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: animateOut,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < -100) animateOut();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C1C1E).withOpacity(0.82)
                                : Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.28 : 0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 6),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(_icon, color: _color, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasTitle)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          widget.title!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1C1C1E),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.65)
                                            : const Color(0xFF3C3C43)
                                                .withOpacity(
                                                    hasTitle ? 0.6 : 0.85),
                                        letterSpacing: -0.1,
                                        height: 1.25,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Undo toast (countdown + action) ───────────────────────────

class _UndoToast extends StatefulWidget {
  const _UndoToast({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.duration,
    required this.onUndo,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onDismissed;

  @override
  State<_UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<_UndoToast>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _countdown;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _dismissed = false;
  bool _undone = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _countdown = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enter,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ));
    _enter.forward();
  }

  void animateOut() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _countdown.stop();
    _enter.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  void _handleUndo() {
    if (_undone || _dismissed) return;
    _undone = true;
    widget.onUndo();
    animateOut();
  }

  @override
  void dispose() {
    _enter.dispose();
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxW = mq.size.width > 600 ? 420.0 : mq.size.width - 40.0;
    final accent = AppTheme.primaryColor;

    return Positioned(
      top: mq.padding.top + 8,
      left: 0,
      right: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E).withOpacity(0.88)
                            : Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.28 : 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _countdown,
                            builder: (_, __) {
                              final remaining = (widget.duration.inMilliseconds *
                                      (1 - _countdown.value) /
                                      1000)
                                  .ceil()
                                  .clamp(0, widget.duration.inSeconds);
                              return SizedBox(
                                width: 36,
                                height: 36,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: 1 - _countdown.value,
                                      strokeWidth: 3,
                                      backgroundColor:
                                          accent.withOpacity(0.15),
                                      valueColor:
                                          AlwaysStoppedAnimation(accent),
                                    ),
                                    Text(
                                      '$remaining',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1C1C1E),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.65)
                                        : const Color(0xFF3C3C43)
                                            .withOpacity(0.65),
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _handleUndo,
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              widget.actionLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
