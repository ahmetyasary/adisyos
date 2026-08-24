import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/features/ordi/presentation/ordi_launcher.dart';
import 'package:orderix/models/app_role.dart';
import 'package:orderix/navigation/app_bottom_bar.dart';
import 'package:orderix/navigation/app_sections.dart';
import 'package:orderix/navigation/app_sidebar.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/subscription_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/views/auth_screen.dart';
import 'package:orderix/views/pin_screen.dart';
import 'package:orderix/views/paywall_sheet.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Apple-inspired design tokens ──────────────────────────────
Color get _bg => AppColors.scaffold;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
Color get _labelPrimary => AppColors.textPrimary;
Color get _labelSecondary => AppColors.textSec;

/// Width below which the sidebar collapses into a hamburger [Drawer].
/// Above it, the sidebar is permanent (tablet/desktop).
const double _kPermanentSidebarBreakpoint = 600;

/// The app's main shell. Hosts a persistent sidebar and swaps the selected
/// section's view into the content area in place (no page push). Replaces the
/// old feature-grid `HomeView` as the landing route and owns the subscription
/// paywall gate + logout flow that used to live there.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialSectionId});

  /// Optional deep-link target (e.g. '/reports' route → 'reports'). Clamped to
  /// a role-permitted section; falls back to the role's landing section.
  final String? initialSectionId;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late Timer _timer;
  Worker? _entitlementWorker;
  bool _paywallShown = false;

  /// The user-selected section. Null until first selection — until then the
  /// content resolves to the deep-link target or the role's landing section.
  String? _selectedId;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedId = widget.initialSectionId;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _enforcePaywall();
    });

    _entitlementWorker = ever(
      SubscriptionService.to.customerInfo,
      (_) => _enforcePaywall(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _enforcePaywall());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entitlementWorker?.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SubscriptionService.to.refreshCustomerInfo();
      _enforcePaywall();
    }
  }

  // ── Paywall gate (migrated from HomeView) ────────────────────

  /// Centralised gate. Idempotent — the `_paywallShown` flag prevents
  /// stacking sheets when multiple triggers fire in quick succession.
  void _enforcePaywall() {
    if (!mounted || _paywallShown) return;
    if (!AuthController.to.isAuthenticated) return;
    if (SubscriptionService.to.hasAccess) return;

    if (!SubscriptionService.to.receiptSyncSettled) {
      SubscriptionService.to.syncFromReceipt().then((_) {
        if (mounted) _enforcePaywall();
      });
      return;
    }

    _paywallShown = true;
    showPaywallSheet(context, dismissible: false).whenComplete(() {
      _paywallShown = false;
      if (mounted &&
          AuthController.to.isAuthenticated &&
          !SubscriptionService.to.hasAccess) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _enforcePaywall());
      }
    });
  }

  // ── Navigation ───────────────────────────────────────────────

  void _select(String id) {
    // Defence in depth: even if the modal paywall is somehow bypassed,
    // every navigation is gated on access.
    if (AuthController.to.isAuthenticated &&
        !SubscriptionService.to.hasAccess) {
      _enforcePaywall();
      return;
    }
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
  }

  // ── Logout (migrated from HomeView) ──────────────────────────

  Future<void> _handleLogout() async {
    // Block logout if any table still has an active order
    final hasOrders =
        TableService.to.tables.any((t) => t['isOccupied'] == true);
    if (hasOrders) {
      Get.dialog(
        Dialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.table_bar_rounded,
                      size: 32, color: Color(0xFFFF3B30)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Açık Sipariş Var',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _labelPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tüm masalar kapatılmadan\nçıkış yapılamaz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _labelSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: Get.back,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Tamam',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final id = _currentIdentifier;
    final dayActive = DayService.to.isDayStartedBy(id);

    if (dayActive) {
      final confirmed = await Get.dialog<bool>(
        Dialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(CupertinoIcons.sun_max_fill,
                      size: 32, color: Color(0xFFFF9500)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Günü Bitir ve Çıkış Yap',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _labelPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktif gününüz var. Çıkış yaparsanız\ngün otomatik olarak bitecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _labelSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Günü Bitir ve Çıkış Yap',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: _labelSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
      await DayService.to.endDay(id);
    }

    // A staff member (signed in via PIN) returns to the PIN screen to switch
    // users — they must NOT sign out the underlying account. An admin fully
    // logs out to the auth screen.
    final isStaffSession = StaffService.to.hasActiveStaff;
    StaffService.to.clearCurrentStaff();
    if (isStaffSession) {
      Get.offAll(() => const PinScreen());
    } else {
      await AuthController.to.logout();
      Get.offAll(() => const AuthScreen());
    }
  }

  /// Unique identifier for the current session's day tracking.
  String get _currentIdentifier {
    final staffName = StaffService.to.currentStaffIdentifier;
    return staffName.isNotEmpty
        ? staffName
        : (AuthController.to.user.value?.email ?? '');
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= _kPermanentSidebarBreakpoint;

    return Obx(() {
      // Explicit deps so tablet sidebar + phone bottom bar both rebuild when
      // the admin reorders navigation (local or realtime).
      SettingsService.to.navOrder.length;
      // Theme epoch: pages read AppColors getters — rebuild shell + section.
      final themeEpoch = SettingsService.to.themeEpoch.value;
      SettingsService.to.themeMode.value;
      // System mode follows OS light/dark without leaving the screen.
      MediaQuery.platformBrightnessOf(context);
      AppColors.syncBrightness(SettingsService.to.resolvedBrightness());

      final AppRole? role = AuthController.to.currentRole;
      final mainSections = sectionsFor(role);
      final footerSections = footerSectionsFor(role);
      final effectiveId =
          resolveSectionFor(role, _selectedId ?? widget.initialSectionId);

      final section = effectiveId == null ? null : sectionById(effectiveId);
      final content = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: section == null
            ? const SizedBox.shrink()
            : KeyedSubtree(
                key: ValueKey('${section.id}-$themeEpoch'),
                child: section.builder(),
              ),
      );

      if (isWide) {
        // Permanent sidebar. The hosted views manage their own top inset via
        // MediaQuery.padding.top, so the content area is NOT wrapped in a top
        // SafeArea (that would double the status-bar gap). The sidebar pads
        // itself internally.
        return Scaffold(
          backgroundColor: _bg,
          body: withOrdiLauncher(
            Row(
              children: [
                AppSidebar(
                  sections: mainSections,
                  footerSections: footerSections,
                  selectedId: effectiveId,
                  collapsed: _collapsed,
                  onSelect: _select,
                  onLogout: _handleLogout,
                  onToggleCollapse: () =>
                      setState(() => _collapsed = !_collapsed),
                ),
                Expanded(
                  child: ShellScope(
                    hasDrawer: false,
                    openDrawer: () {},
                    selectSection: _select,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Mobile / small screens: a bottom tab bar surfaces the most-used
      // sections; the rest live behind a "Daha Fazla" sheet. No drawer, so
      // hosted views render no hamburger (hasDrawer: false).
      final bottomSections = bottomBarSectionsFor(role);
      final moreSections = moreSectionsFor(role);

      return Scaffold(
        backgroundColor: _bg,
        // Inside `body`, so the launcher sits above the bottom bar rather than
        // overlapping its tabs.
        body: withOrdiLauncher(
          ShellScope(
            hasDrawer: false,
            openDrawer: () {},
            selectSection: _select,
            child: content,
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          sections: bottomSections,
          selectedId: effectiveId,
          onSelect: _select,
          onMore: () => showMoreSheet(
            context,
            moreSections: moreSections,
            footerSections: footerSections,
            selectedId: effectiveId,
            notifCount:
                SalesHistoryService.to.getSalesForDate(DateTime.now()).length,
            onSelect: _select,
            onLogout: _handleLogout,
          ),
        ),
      );
    });
  }
}
