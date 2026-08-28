import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/models/app_role.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/views/dashboard_view.dart';
import 'package:orderix/views/tables_view.dart';
import 'package:orderix/views/kitchen_display_view.dart';
import 'package:orderix/views/menu_management_view.dart';
import 'package:orderix/views/digital_menu_view.dart';
import 'package:orderix/views/pending_menu_orders_view.dart';
import 'package:orderix/views/inventory_management_view.dart';
import 'package:orderix/views/day_management_view.dart';
import 'package:orderix/views/reports_view.dart';
import 'package:orderix/views/completed_payments_view.dart';
import 'package:orderix/views/cari_accounts_view.dart';
import 'package:orderix/views/staff_report_view.dart';
import 'package:orderix/views/shift_management_view.dart';
import 'package:orderix/views/notifications_view.dart';
import 'package:orderix/views/settings_view.dart';

/// A single navigable destination in the app shell. Replaces the old
/// feature-card grid + `_navigate()` switch from `home_view.dart`.
class AppSection {
  const AppSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.roles,
    required this.builder,
    this.hidden = false,
    this.footer = false,
  });

  final String id;

  /// Late-evaluated so `.tr` resolves against the current locale.
  final String Function() title;
  final IconData icon;
  final List<AppRole> roles;

  /// Builds the view hosted in the shell content area (always `embedded: true`).
  final Widget Function() builder;

  /// Hidden sections are routable but never shown in the sidebar list.
  final bool hidden;

  /// Footer sections render as small icon buttons at the bottom of the sidebar.
  final bool footer;

  bool allows(AppRole? role) => role != null && roles.contains(role);
}

/// The single source of truth for the app's navigable sections.
final List<AppSection> appSections = [
  AppSection(
    id: 'dashboard',
    title: () => 'Ana Ekran',
    icon: CupertinoIcons.square_grid_2x2_fill,
    roles: const [AppRole.admin],
    builder: () => const DashboardView(embedded: true),
  ),
  AppSection(
    id: 'tables',
    title: () => 'tables'.tr,
    icon: Icons.table_bar_rounded,
    roles: const [AppRole.admin, AppRole.staff],
    builder: () => const TablesView(embedded: true),
  ),
  AppSection(
    id: 'kitchen',
    title: () => 'Mutfak',
    icon: CupertinoIcons.flame_fill,
    roles: const [AppRole.admin, AppRole.kitchen],
    builder: () => const KitchenDisplayView(embedded: true),
  ),
  AppSection(
    id: 'menu',
    title: () => 'menu'.tr,
    icon: CupertinoIcons.square_list_fill,
    roles: const [AppRole.admin],
    builder: () => const MenuManagementView(embedded: true),
  ),
  AppSection(
    id: 'pending_orders',
    title: () => 'Bekleyen siparişler',
    icon: CupertinoIcons.bell_fill,
    roles: const [AppRole.admin, AppRole.staff],
    builder: () => const PendingMenuOrdersView(embedded: true),
  ),
  AppSection(
    id: 'digital_menu',
    title: () => 'digital_menu'.tr,
    icon: CupertinoIcons.qrcode,
    roles: const [AppRole.admin],
    builder: () => const DigitalMenuView(embedded: true),
  ),
  AppSection(
    id: 'inventory',
    title: () => 'Stoklar',
    icon: CupertinoIcons.cube_box_fill,
    roles: const [AppRole.admin],
    builder: () => const InventoryManagementView(embedded: true),
  ),
  AppSection(
    id: 'day_management',
    title: () => 'Günler',
    icon: CupertinoIcons.sun_max_fill,
    roles: const [AppRole.admin],
    builder: () => const DayManagementView(embedded: true),
  ),
  AppSection(
    id: 'reports',
    title: () => 'reports'.tr,
    icon: CupertinoIcons.chart_bar_alt_fill,
    roles: const [AppRole.admin],
    builder: () => const ReportsView(embedded: true),
  ),
  AppSection(
    id: 'completed_payments',
    title: () => 'Tamamlanan ödemeler',
    icon: CupertinoIcons.checkmark_seal_fill,
    roles: const [AppRole.admin],
    builder: () => const CompletedPaymentsView(embedded: true),
  ),
  AppSection(
    id: 'cari_accounts',
    title: () => 'Cari Hesaplar',
    icon: CupertinoIcons.person_crop_circle_badge_checkmark,
    roles: const [AppRole.admin, AppRole.staff],
    builder: () => const CariAccountsView(embedded: true),
  ),
  AppSection(
    id: 'staff_report',
    title: () => 'Personel',
    icon: CupertinoIcons.person_2_fill,
    roles: const [AppRole.admin],
    builder: () => const StaffReportView(embedded: true),
  ),
  // Hidden: not surfaced in the sidebar (matches the old grid's hidden flag),
  // but kept here so it stays routable if surfaced later.
  AppSection(
    id: 'shifts',
    title: () => 'Vardiya',
    icon: CupertinoIcons.clock_fill,
    roles: const [AppRole.admin],
    hidden: true,
    builder: () => const ShiftManagementView(embedded: true),
  ),
  // ── Footer sections ─────────────────────────────────────────
  AppSection(
    id: 'notifications',
    title: () => 'Bildirimler',
    icon: CupertinoIcons.bell,
    roles: const [AppRole.admin],
    footer: true,
    builder: () => const NotificationsView(embedded: true),
  ),
  AppSection(
    id: 'settings',
    title: () => 'settings'.tr,
    icon: CupertinoIcons.gear,
    roles: const [AppRole.admin],
    footer: true,
    builder: () => const SettingsView(embedded: true),
  ),
];

/// Look up a section by id (null if unknown).
AppSection? sectionById(String id) {
  for (final s in appSections) {
    if (s.id == id) return s;
  }
  return null;
}

/// Applies the tenant's saved sidebar order. Unknown / new sections stay
/// after the saved ids, in their built-in relative order.
List<AppSection> _withNavOrder(List<AppSection> list) {
  final order = SettingsService.to.navOrder.toList();
  if (order.isEmpty) return list;
  final byId = {for (final s in list) s.id: s};
  final out = <AppSection>[];
  for (final id in order) {
    final s = byId.remove(id);
    if (s != null) out.add(s);
  }
  out.addAll(list.where((s) => byId.containsKey(s.id)));
  return out;
}

/// Sections to show in the sidebar's main list for [role]
/// (role-permitted, visible, non-footer).
bool _isSectionAvailable(AppSection section, AppRole? role) =>
    section.allows(role) &&
    !section.hidden &&
    (section.id != 'cari_accounts' ||
        SettingsService.to.cariAccountsEnabled.value);

List<AppSection> sectionsFor(AppRole? role) => _withNavOrder(
      appSections
          .where((s) => _isSectionAvailable(s, role) && !s.footer)
          .toList(),
    );

/// Sections to show in the sidebar's footer for [role].
List<AppSection> footerSectionsFor(AppRole? role) =>
    appSections.where((s) => _isSectionAvailable(s, role) && s.footer).toList();

/// The most-used sections for the mobile bottom bar = first N entries of the
/// admin's custom [sectionsFor] order (not a fixed id set). Everything after
/// that lives behind "Daha Fazla".
const int _bottomBarSlotCount = 4;

/// Up to [_bottomBarSlotCount] role-permitted sections for the mobile bottom bar,
/// in the tenant's saved nav order.
List<AppSection> bottomBarSectionsFor(AppRole? role) =>
    sectionsFor(role).take(_bottomBarSlotCount).toList();

/// Role-permitted main sections that are NOT in the bottom bar — they populate
/// the first group of the mobile "Daha Fazla" sheet.
List<AppSection> moreSectionsFor(AppRole? role) {
  final all = sectionsFor(role);
  if (all.length <= _bottomBarSlotCount) return const [];
  return all.skip(_bottomBarSlotCount).toList();
}

/// The section a user of [role] should land on when entering the shell.
/// Admin → Dashboard when permitted, otherwise the first ordered section.
String? landingSectionFor(AppRole? role) {
  final list = sectionsFor(role);
  if (list.isEmpty) return null;
  for (final s in list) {
    if (s.id == 'dashboard') return s.id;
  }
  return list.first.id;
}

/// Clamp a requested [sectionId] to one the [role] may actually open.
/// Falls back to the role's landing section when the request is missing,
/// unknown, hidden, or not permitted.
String? resolveSectionFor(AppRole? role, String? sectionId) {
  if (sectionId != null) {
    final s = sectionById(sectionId);
    if (s != null && _isSectionAvailable(s, role)) return s.id;
  }
  return landingSectionFor(role);
}
