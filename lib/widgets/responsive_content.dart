import 'package:flutter/material.dart';

/// Content-type presets for horizontal width caps on large screens (tablets,
/// desktop). Keeps forms/lists/grids from stretching edge-to-edge on iPad.
enum ContentWidth {
  /// 640 — settings, auth, short form content.
  form,

  /// 820 — list-heavy content (menu, inventory, legal).
  list,

  /// 1040 — dashboard with grids and stats (home, reports).
  dashboard,

  /// 1200 — dense grids (tables, kitchen display) and split-view details.
  wide,
}

/// Wraps [child] so its maximum horizontal extent is limited to a preset
/// based on content type. On phones (width ≤ preset) this is a no-op; on
/// tablets it centers the column, matching iOS/iPadOS patterns where form
/// and list content sit in a centered reading column.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.width = ContentWidth.form,
  });

  final Widget child;
  final ContentWidth width;

  double get _max => switch (width) {
        ContentWidth.form => 640,
        ContentWidth.list => 820,
        ContentWidth.dashboard => 1040,
        ContentWidth.wide => 1200,
      };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _max),
        child: child,
      ),
    );
  }
}
