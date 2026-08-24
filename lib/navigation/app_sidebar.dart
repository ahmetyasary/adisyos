import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/navigation/app_sections.dart';
import 'package:orderix/services/digital_menu_order_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/brand_assets.dart';

// ── Apple-inspired design tokens ──────────────────────────────
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
Color get _orangeTint =>
    AppColors.isDark ? const Color(0xFF3A2A14) : const Color(0xFFFFF4E0);
Color get _labelPrimary => AppColors.textPrimary;
Color get _labelSecondary => AppColors.textSec;
Color get _separator => AppColors.border;
const _red = Color(0xFFFF3B30);

const double kSidebarExpandedWidth = 248;
const double kSidebarCollapsedWidth = 76;

// Inner content width of an expanded [_SidebarRow]: the expanded sidebar width
// minus the row's horizontal margin (12 each side) and padding (14 each side).
// Used to pin the row's layout width during the collapse/expand animation so
// the transient narrow constraint never overflows the Row.
const double _expandedRowContentWidth =
    kSidebarExpandedWidth - (12 * 2) - (14 * 2);

/// The shell's left navigation sidebar. Permanent on tablet/desktop,
/// hosted inside a [Drawer] on phone. Flat, role-filtered, collapsible.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.sections,
    required this.footerSections,
    required this.selectedId,
    required this.collapsed,
    required this.onSelect,
    required this.onLogout,
    this.onToggleCollapse,
  });

  final List<AppSection> sections;
  final List<AppSection> footerSections;
  final String? selectedId;
  final bool collapsed;
  final void Function(String id) onSelect;
  final VoidCallback onLogout;

  /// When null, the collapse toggle is hidden (e.g. inside a mobile drawer).
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: collapsed ? kSidebarCollapsedWidth : kSidebarExpandedWidth,
      decoration: BoxDecoration(
        color: _card,
        border: Border(right: BorderSide(color: _separator, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 16, offset: Offset(2, 0)),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Divider(height: 1, thickness: 0.5, color: _separator),
            Expanded(
              child: Obx(() {
                // Touch pending list so title count rebuilds when QR orders arrive.
                if (Get.isRegistered<DigitalMenuOrderService>()) {
                  DigitalMenuOrderService.to.pending.length;
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    for (final s in sections)
                      _SidebarRow(
                        icon: s.icon,
                        label: s.title(),
                        active: s.id == selectedId,
                        collapsed: collapsed,
                        badgeCount: s.id == 'pending_orders'
                            ? DigitalMenuOrderService.to.pendingCount
                            : 0,
                        onTap: () => onSelect(s.id),
                      ),
                  ],
                );
              }),
            ),
            Divider(height: 1, thickness: 0.5, color: _separator),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Tapping the logo toggles the sidebar (replaces the separate chevron
    // button). Falls back to a plain logo when collapsing isn't available
    // (e.g. hosted inside a mobile drawer).
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
        child: collapsed
            ? Center(
                child: _LogoButton(
                  height: 30,
                  mark: true,
                  onTap: onToggleCollapse,
                ),
              )
            : _PinnedExpandedRow(
                width: kSidebarExpandedWidth - (16 * 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _LogoButton(
                    height: 24,
                    mark: false,
                    onTap: onToggleCollapse,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in footerSections)
            _SidebarRow(
              icon: s.icon,
              label: s.title(),
              active: s.id == selectedId,
              collapsed: collapsed,
              onTap: () => onSelect(s.id),
            ),
          _SidebarRow(
            icon: CupertinoIcons.square_arrow_right,
            label: 'Çıkış Yap',
            active: false,
            collapsed: collapsed,
            foreground: _red,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.foreground,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final Color? foreground;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? (active ? _orange : _labelSecondary);
    final textColor = foreground ?? (active ? _orange : _labelPrimary);

    Widget iconWidget = Icon(icon, size: collapsed ? 22 : 20, color: fg);
    if (badgeCount > 0 && collapsed) {
      iconWidget = SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: fg),
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final row = collapsed
        ? Center(child: iconWidget)
        : _PinnedExpandedRow(
            width: _expandedRowContentWidth,
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          );

    final content = Container(
      height: 46,
      margin:
          EdgeInsets.symmetric(horizontal: collapsed ? 12 : 12, vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14),
      decoration: BoxDecoration(
        color: active ? _orangeTint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: row,
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );

    return collapsed ? Tooltip(message: label, child: tappable) : tappable;
  }
}

/// Lays out an expanded-state sidebar row at its full [width] and clips any
/// overflow, instead of letting the Row overflow.
///
/// The sidebar's width is animated (via [AnimatedContainer]) while the
/// `collapsed` flag flips instantly, so for a few frames an expanded row is
/// rendered inside a container that is still mid-animation and too narrow.
/// Pinning the row to its final expanded width keeps the Row's own layout
/// valid, and the surrounding clip hides the part that doesn't fit yet. At full
/// width [width] matches the available space, so nothing is ever clipped.
class _PinnedExpandedRow extends StatelessWidget {
  const _PinnedExpandedRow({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A non-scrolling horizontal viewport: it fills the (animating) available
    // width, lays the fixed-width child out at its full expanded width, and
    // clips the overflow silently — no RenderFlex overflow warnings. The cross
    // axis (height) is passed straight through to the child, so this works
    // whether the parent gives a bounded height (header/row) or an unbounded
    // one (footer column).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(width: width, child: child),
    );
  }
}

/// The sidebar's brand logo, doubling as the collapse/expand toggle when
/// [onTap] is provided (null → a plain, non-interactive logo).
class _LogoButton extends StatelessWidget {
  const _LogoButton({
    required this.height,
    required this.mark,
    this.onTap,
  });

  final double height;
  final bool mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logo = mark
        ? BrandMark(size: height)
        : BrandWordmark(height: height);
    if (onTap == null) return logo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: logo,
        ),
      ),
    );
  }
}
