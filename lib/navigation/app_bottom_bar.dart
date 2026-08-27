import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/navigation/app_sections.dart';
import 'package:orderix/services/cari_service.dart';
import 'package:orderix/services/digital_menu_order_service.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Apple-inspired design tokens ──────────────────────────────
Color get _card => AppColors.card;
Color get _bg => AppColors.scaffold;
const _orange = Color(0xFFFF9500);
Color get _labelPrimary => AppColors.textPrimary;
Color get _labelSecondary => AppColors.textSec;
Color get _separator => AppColors.border;
const _red = Color(0xFFFF3B30);
Color get _iconChipBg => AppColors.chipBg;
Color get _iconChipFg => AppColors.textPrimary;

int _pendingOrdersCount() {
  if (!Get.isRegistered<DigitalMenuOrderService>()) return 0;
  return DigitalMenuOrderService.to.pendingCount;
}

int _openCariAccountsCount() {
  if (!Get.isRegistered<CariService>()) return 0;
  return CariService.to.openAccountCount;
}

/// The mobile shell's bottom tab bar. Shows the most-used, role-permitted
/// sections plus a trailing "Daha Fazla" tab that opens [showMoreSheet].
/// Replaces the drawer-hosted sidebar on phones / small screens.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.onSelect,
    required this.onMore,
  });

  final List<AppSection> sections;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = _pendingOrdersCount();
      final openCariAccounts = _openCariAccountsCount();
      final pendingOnBar = sections.any((s) => s.id == 'pending_orders');
      // "Daha Fazla" is active whenever the current section isn't a bar tab.
      final moreActive = !sections.any((s) => s.id == selectedId);

      return Container(
        decoration: BoxDecoration(
          color: _card,
          border: Border(top: BorderSide(color: _separator, width: 0.5)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final s in sections)
                  Expanded(
                    child: _BarItem(
                      icon: s.icon,
                      label: s.title(),
                      active: s.id == selectedId,
                      badgeCount: s.id == 'pending_orders' && pending > 0
                          ? pending
                          : s.id == 'cari_accounts'
                              ? openCariAccounts
                              : 0,
                      onTap: () => onSelect(s.id),
                    ),
                  ),
                Expanded(
                  child: _BarItem(
                    icon: CupertinoIcons.ellipsis,
                    label: 'Daha Fazla',
                    active: moreActive,
                    badgeCount: !pendingOnBar && pending > 0 ? pending : 0,
                    onTap: onMore,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = active ? _orange : _labelSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 26,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: _TabBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

// ── "Daha Fazla" sheet ────────────────────────────────────────

/// Opens the iOS-style grouped sheet listing the less-used destinations.
/// Selecting a row closes the sheet first, then routes via [onSelect]/[onLogout].
Future<void> showMoreSheet(
  BuildContext context, {
  required List<AppSection> moreSections,
  required List<AppSection> footerSections,
  required String? selectedId,
  required int notifCount,
  required void Function(String id) onSelect,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _MoreSheet(
      moreSections: moreSections,
      footerSections: footerSections,
      selectedId: selectedId,
      notifCount: notifCount,
      onSelect: (id) {
        Navigator.of(sheetCtx).pop();
        onSelect(id);
      },
      onLogout: () {
        Navigator.of(sheetCtx).pop();
        onLogout();
      },
    ),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.moreSections,
    required this.footerSections,
    required this.selectedId,
    required this.notifCount,
    required this.onSelect,
    required this.onLogout,
  });

  final List<AppSection> moreSections;
  final List<AppSection> footerSections;
  final String? selectedId;
  final int notifCount;
  final void Function(String id) onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: _separator,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Daha Fazla',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _labelPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    if (moreSections.isNotEmpty) ...[
                      _Group(
                        children: _withDividers([
                          for (final s in moreSections)
                            _MoreRow(
                              icon: s.icon,
                              label: s.title(),
                              active: s.id == selectedId,
                              badgeCount: s.id == 'pending_orders'
                                  ? _pendingOrdersCount()
                                  : s.id == 'cari_accounts'
                                      ? _openCariAccountsCount()
                                      : 0,
                              onTap: () => onSelect(s.id),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (footerSections.isNotEmpty) ...[
                      _Group(
                        children: _withDividers([
                          for (final s in footerSections)
                            _MoreRow(
                              icon: s.icon,
                              label: s.title(),
                              active: s.id == selectedId,
                              badgeCount:
                                  s.id == 'notifications' ? notifCount : 0,
                              onTap: () => onSelect(s.id),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _Group(
                      children: [
                        _MoreRow(
                          icon: CupertinoIcons.square_arrow_right,
                          label: 'Çıkış Yap',
                          isLogout: true,
                          onTap: onLogout,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interleaves inset hairline dividers between rows (iOS grouped list).
  static List<Widget> _withDividers(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) out.add(const _RowDivider());
    }
    return out;
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => Padding(
        // Inset to align under the label, past the 40px badge + 12px gap.
        padding: EdgeInsets.only(left: 68),
        child: Divider(height: 0.5, thickness: 0.5, color: _separator),
      );
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badgeCount = 0,
    this.isLogout = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final int badgeCount;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _orange.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLogout ? _red.withValues(alpha: 0.10) : _iconChipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(icon, size: 20, color: isLogout ? _red : _iconChipFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isLogout ? FontWeight.w700 : FontWeight.w600,
                    color: isLogout ? _red : _labelPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (badgeCount > 0) _CountBadge(count: badgeCount),
              if (!isLogout)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.chevron_right,
                      size: 22, color: _labelSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE5E5EA),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(CupertinoIcons.xmark, size: 18, color: _labelSecondary),
        ),
      ),
    );
  }
}
