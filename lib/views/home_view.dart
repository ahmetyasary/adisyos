import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/views/kitchen_display_view.dart';
import 'package:adisyos/views/inventory_management_view.dart';
import 'package:adisyos/views/staff_report_view.dart';
import 'package:adisyos/views/shift_management_view.dart';
import 'package:adisyos/views/dashboard_view.dart';
import 'package:adisyos/views/menu_management_view.dart';
import 'package:adisyos/views/notifications_view.dart';
import 'package:adisyos/views/reports_view.dart';
import 'package:adisyos/views/settings_view.dart';
import 'package:adisyos/views/tables_view.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bg           = Color(0xFFF5F6FA);
const _card         = Colors.white;
const _orange       = Color(0xFFF5A623);
const _orangeLight  = Color(0xFFFFF3E0);
const _textPrimary  = Color(0xFF1A1A2E);
const _textSec      = Color(0xFF9B9B9B);
const _border       = Color(0xFFEEEEEE);

// ──────────────────────────────────────────────────────────────
// HomeView
// ──────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _loadCompanyName();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _companyName = prefs.getString('companyName') ?? '');
    }
  }

  // ── Navigation ───────────────────────────────────────────────

  void _navigate(String route) {
    switch (route) {
      case 'tables':    Get.to(() => const TablesView()); break;
      case 'menu':      Get.to(() => const MenuManagementView()); break;
      case 'reports':   Get.to(() => const ReportsView()); break;
      case 'settings':  Get.to(() => const SettingsView()); break;
      case 'notifications': Get.to(() => const NotificationsView()); break;
      case 'kitchen':   Get.to(() => const KitchenDisplayView()); break;
      case 'inventory': Get.to(() => const InventoryManagementView()); break;
      case 'staff_report': Get.to(() => const StaffReportView()); break;
      case 'shifts':    Get.to(() => const ShiftManagementView()); break;
      case 'dashboard': Get.to(() => const DashboardView()); break;
    }
  }

  // ── Role-based feature cards ─────────────────────────────────

  List<Map<String, dynamic>> _featureCards(AppRole? role) {
    final all = [
      {
        'title':    'tables'.tr,
        'subtitle': 'Masaları yönet ve sipariş al',
        'btnLabel': 'Masalara Git',
        'icon':     Icons.table_bar_rounded,
        'route':    'tables',
        'active':   true,
        'primary':  true,
        'roles':    [AppRole.admin, AppRole.staff],
      },
      {
        'title':    'reports'.tr,
        'subtitle': 'Günlük, aylık ve yıllık raporlar',
        'btnLabel': 'Raporları Gör',
        'icon':     Icons.bar_chart_rounded,
        'route':    'reports',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'menu'.tr,
        'subtitle': 'Ürün ve kategori yönetimi',
        'btnLabel': 'Menüyü Düzenle',
        'icon':     Icons.restaurant_menu_rounded,
        'route':    'menu',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'staff'.tr,
        'subtitle': 'Personel hesapları ve roller',
        'btnLabel': 'coming_soon'.tr,
        'icon':     Icons.people_rounded,
        'route':    'staff',
        'active':   false,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'settings'.tr,
        'subtitle': 'Şirket ve sistem ayarları',
        'btnLabel': 'Ayarları Aç',
        'icon':     Icons.settings_rounded,
        'route':    'settings',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin, AppRole.staff],
      },
      {
        'title':    'notifications'.tr,
        'subtitle': 'Son aktivite ve bildirimler',
        'btnLabel': 'Bildirimleri Gör',
        'icon':     Icons.notifications_rounded,
        'route':    'notifications',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'Mutfak',
        'subtitle': 'Sipariş durumunu takip et',
        'btnLabel': 'Mutfak Ekranı',
        'icon':     Icons.kitchen_rounded,
        'route':    'kitchen',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin, AppRole.staff],
      },
      {
        'title':    'Stoklar',
        'subtitle': 'Ürün stok yönetimi',
        'btnLabel': 'Stok Yönetimi',
        'icon':     Icons.inventory_2_rounded,
        'route':    'inventory',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'Personel',
        'subtitle': 'Personel performans raporu',
        'btnLabel': 'Raporu Gör',
        'icon':     Icons.leaderboard_rounded,
        'route':    'staff_report',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
      {
        'title':    'Vardiya',
        'subtitle': 'Giriş/çıkış ve mola takibi',
        'btnLabel': 'Vardiyam',
        'icon':     Icons.schedule_rounded,
        'route':    'shifts',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin, AppRole.staff],
      },
      {
        'title':    'Dashboard',
        'subtitle': 'Canlı doluluk ve satış takibi',
        'btnLabel': 'Canlı İzle',
        'icon':     Icons.dashboard_rounded,
        'route':    'dashboard',
        'active':   true,
        'primary':  false,
        'roles':    [AppRole.admin],
      },
    ];

    if (role == null) return [];
    return all
        .where((c) => (c['roles'] as List<AppRole>).contains(role))
        .toList();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              currentTime: _currentTime,
              companyName: _companyName,
              onNavigate: _navigate,
            ),
            Expanded(
              child: Obx(() {
                final role = AuthController.to.currentRole;
                final cards = _featureCards(role);
                return _MainContent(
                  cards: cards,
                  onNavigate: _navigate,
                );
              }),
            ),
            _Footer(companyName: _companyName),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _Footer
// ──────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.companyName});
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final name =
        companyName.isNotEmpty ? companyName : 'Şirket Adınızı Giriniz';

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // LEFT: contact
          const Icon(Icons.support_agent_outlined, size: 13, color: _textSec),
          const SizedBox(width: 5),
          Text(
            'customer_service'.tr,
            style: const TextStyle(fontSize: 11, color: _textSec),
          ),

          const Spacer(),

          // CENTER: company name
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // RIGHT: version
          Text(
            'Adisyos v0.1 Beta · by Smartlogy',
            style: const TextStyle(fontSize: 11, color: _textSec),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _TopBar
// ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentTime,
    required this.companyName,
    required this.onNavigate,
  });

  final DateTime currentTime;
  final String companyName;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // ── Brand ─────────────────────────────────────
          Text(
            'adisyos',
            style: GoogleFonts.righteous(
              fontSize: 24,
              color: _orange,
              letterSpacing: 2,
            ),
          ),

          const Spacer(),

          // ── Clock ─────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('HH:mm:ss').format(currentTime),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: 1,
                ),
              ),
              Text(
                DateFormat('dd MMM, EEE', Get.locale?.languageCode)
                    .format(currentTime),
                style: const TextStyle(fontSize: 10, color: _textSec),
              ),
            ],
          ),

          const Spacer(),

          // ── User info ──────────────────────────────────
          Obx(() {
            final user = AuthController.to.user.value;
            final email = user?.email ?? '';
            final roleLabel = user?.role.name ?? '';
            final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

            return Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      email.split('@').first,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      roleLabel,
                      style: const TextStyle(fontSize: 11, color: _textSec),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _orangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Settings button (replaced ···) ────────
                GestureDetector(
                  onTap: () => onNavigate('settings'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: _textSec,
                      size: 18,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _MainContent
// ──────────────────────────────────────────────────────────────

class _MainContent extends StatelessWidget {
  const _MainContent({required this.cards, required this.onNavigate});

  final List<Map<String, dynamic>> cards;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(),
          const SizedBox(height: 24),
          _FeatureGrid(cards: cards, onNavigate: onNavigate),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _StatsRow
// ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tables   = TableService.to.tables;
      final occupied = tables.where((t) => t['isOccupied'] == true).length;
      final total    = tables.length;

      // Today's total from sales history
      final today = DateTime.now();
      final todaySales = SalesHistoryService.to.sales.where((s) {
        final ts = DateTime.tryParse(s['date'] as String? ?? '');
        return ts != null &&
            ts.year == today.year &&
            ts.month == today.month &&
            ts.day == today.day;
      }).fold<double>(
          0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));

      return LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          return Column(children: [
            _StatCard(
              icon: Icons.table_bar_rounded,
              iconColor: const Color(0xFF5DADE2),
              label: 'Toplam Masa',
              value: '$total',
            ),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.circle,
              iconColor: const Color(0xFF52C97F),
              label: 'Dolu Masa',
              value: '$occupied / $total',
            ),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.payments_rounded,
              iconColor: _orange,
              label: 'Bugünkü Satış',
              value: '₺${todaySales.toStringAsFixed(2)}',
            ),
          ]);
        }
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.table_bar_rounded,
                iconColor: const Color(0xFF5DADE2),
                label: 'Toplam Masa',
                value: '$total',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.circle,
                iconColor: const Color(0xFF52C97F),
                label: 'Dolu Masa',
                value: '$occupied / $total',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.payments_rounded,
                iconColor: _orange,
                label: 'Bugünkü Satış',
                value: '₺${todaySales.toStringAsFixed(2)}',
              ),
            ),
          ],
        );
      });
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x08000000), blurRadius: 4,  offset: Offset(0, 2)),
          BoxShadow(color: Colors.white,      blurRadius: 0,  offset: Offset(0, -1), spreadRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: _textSec)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _FeatureGrid
// ──────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.cards, required this.onNavigate});

  final List<Map<String, dynamic>> cards;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 500
          ? 1
          : constraints.maxWidth < 800
              ? 2
              : 3;
      final spacing = 16.0;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards.map((card) {
          final width =
              (constraints.maxWidth - spacing * (cols - 1)) / cols;
          return SizedBox(
            width: width,
            height: 200,
            child: _FeatureCard(
              card: card,
              onTap: (card['active'] as bool)
                  ? () => onNavigate(card['route'] as String)
                  : null,
            ),
          );
        }).toList(),
      );
    });
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.card, this.onTap});

  final Map<String, dynamic> card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = card['primary'] as bool;
    final isActive  = card['active'] as bool;
    final icon      = card['icon'] as IconData;
    final title     = card['title'] as String;
    final subtitle  = card['subtitle'] as String;
    final btnLabel  = card['btnLabel'] as String;

    final bgColor   = isPrimary ? _orange : _card;
    final titleColor  = isPrimary ? Colors.white : _textPrimary;
    final subColor    = isPrimary
        ? Colors.white.withOpacity(0.75)
        : _textSec;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isPrimary
              ? [
                  BoxShadow(color: Color(0x55F5A623), blurRadius: 20, offset: Offset(0, 8)),
                  BoxShadow(color: Color(0x22F5A623), blurRadius: 6,  offset: Offset(0, 2)),
                ]
              : [
                  BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7)),
                  BoxShadow(color: Color(0x08000000), blurRadius: 5,  offset: Offset(0, 2)),
                  BoxShadow(color: Colors.white,      blurRadius: 0,  offset: Offset(0, -1)),
                ],
        ),
        padding: const EdgeInsets.all(22),
        child: Stack(
          children: [
            // Ghost icon (decorative)
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 100,
                color: isPrimary
                    ? Colors.white.withOpacity(0.12)
                    : _textSec.withOpacity(0.07),
              ),
            ),

            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: subColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Action button
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white
                        : isActive
                            ? _orangeLight
                            : _border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    btnLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? _orange
                          : isActive
                              ? _orange
                              : _textSec,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
