import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Exposes the surrounding [AppShell]'s drawer controls to views hosted in the
/// shell content area. Needed because each hosted view is itself a [Scaffold],
/// so `Scaffold.of(context)` from inside a view resolves to that inner
/// scaffold (which has no drawer) rather than the shell's outer one.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.hasDrawer,
    required this.openDrawer,
    required this.selectSection,
    required super.child,
  });

  /// True only when the shell is in mobile/drawer mode (a hamburger is needed).
  final bool hasDrawer;

  /// Opens the shell's drawer.
  final VoidCallback openDrawer;

  /// Navigates the shell to [id] (swaps the hosted view in place). Lets a
  /// hosted view jump to another section — e.g. the dashboard's bell → notifications.
  final void Function(String id) selectSection;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      hasDrawer != oldWidget.hasDrawer ||
      openDrawer != oldWidget.openDrawer ||
      selectSection != oldWidget.selectSection;
}

/// The leading button in a top-level view's header.
///
/// * Standalone (not embedded): a back chevron that pops the route.
/// * Embedded in the shell on mobile: a hamburger that opens the shell drawer.
/// * Embedded in the shell on tablet/desktop (permanent sidebar): nothing.
class ShellLeading extends StatelessWidget {
  const ShellLeading({
    super.key,
    required this.embedded,
    this.color = const Color(0xFF1C1C1E),
  });

  final bool embedded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return IconButton(
        icon: Icon(CupertinoIcons.chevron_back, size: 20, color: color),
        onPressed: () => Get.back(),
      );
    }

    final shell = ShellScope.maybeOf(context);
    if (shell != null && shell.hasDrawer) {
      return IconButton(
        icon: Icon(CupertinoIcons.line_horizontal_3, size: 22, color: color),
        onPressed: shell.openDrawer,
      );
    }

    // Embedded with a permanent sidebar — no leading button needed.
    return const SizedBox(width: 8);
  }
}
