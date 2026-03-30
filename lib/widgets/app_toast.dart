import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/app_theme.dart';

enum ToastType { success, warning, error, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _key = GlobalKey<_ToastState>();

  static void success(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.success, duration: duration);

  static void warning(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.warning, duration: duration);

  static void error(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.error, duration: duration);

  static void info(String message, {String? title, Duration? duration}) =>
      _show(message, title: title, type: ToastType.info, duration: duration);

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
        return Icons.check_circle_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.info:
        return Icons.info_rounded;
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
