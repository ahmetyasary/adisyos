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
const _bg          = Color(0xFFF5F6FA);
const _card        = Colors.white;
const _orange      = Color(0xFFF5A623);
const _orangeLight = Color(0xFFFFF3E0);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec     = Color(0xFF9B9B9B);
const _border      = Color(0xFFEEEEEE);

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

  void _navigate(String route) {
    switch (route) {
      case 'tables':        Get.to(() => const TablesView()); break;
      case 'menu':          Get.to(() => const MenuManagementView()); break;
      case 'reports':       Get.to(() => const ReportsView()); break;
      case 'settings':      Get.to(() => const SettingsView()); break;
      case 'notifications': Get.to(() => const NotificationsView()); break;
      case 'kitchen':       Get.to(() => const KitchenDisplayView()); break;
      case 'inventory':     Get.to(() => const InventoryManagementView()); break;
      case 'staff_report':  Get.to(() => const StaffReportView()); break;
      case 'shifts':        Get.to(() => const ShiftManagementView()); break;
      case 'dashboard':     Get.to(() => const DashboardView()); break;
    }
  }

  List<Map<String, dynamic>> _featureCards(AppRole? role) {
    final all = [
      {
        'title':   'tables'.tr,
        'subtitle':'Masaları yönet ve sipariş al',
        'icon':    Icons.table_bar_rounded,
        'color':   _orange,
        'route':   'tables',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'reports'.tr,
        'subtitle':'Günlük, aylık ve yıllık raporlar',
        'icon':    Icons.bar_chart_rounded,
        'color':   const Color(0xFF5DADE2),
        'route':   'reports',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'menu'.tr,
        'subtitle':'Ürün ve kategori yönetimi',
        'icon':    Icons.restaurant_menu_rounded,
        'color':   const Color(0xFF52C97F),
        'route':   'menu',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Mutfak',
        'subtitle':'Sipariş durumunu takip et',
        'icon':    Icons.kitchen_rounded,
        'color':   const Color(0xFFE74C3C),
        'route':   'kitchen',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'Stoklar',
        'subtitle':'Ürün stok yönetimi',
        'icon':    Icons.inventory_2_rounded,
        'color':   const Color(0xFF8E44AD),
        'route':   'inventory',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Personel',
        'subtitle':'Personel performans raporu',
        'icon':    Icons.leaderboard_rounded,
        'color':   const Color(0xFFF39C12),
        'route':   'staff_report',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Vardiya',
        'subtitle':'Giriş/çıkış ve mola takibi',
        'icon':    Icons.schedule_rounded,
        'color':   const Color(0xFF1ABC9C),
        'route':   'shifts',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'Dashboard',
        'subtitle':'Canlı doluluk ve satış takibi',
        'icon':    Icons.dashboard_rounded,
        'color':   const Color(0xFF2C3E50),
        'route':   'dashboard',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'staff'.tr,
        'subtitle':'Personel hesapları ve roller',
        'icon':    Icons.people_rounded,
        'color':   _textSec,
        'route':   'staff',
        'active':  false,
        'primary': false,
        'roles':   [AppRole.admin],
      },
    ];

    if (role == null) return [];
    return all.where((c) => (c['roles'] as List<AppRole>).contains(role)).toList();
  }

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
                return _MainContent(cards: cards, onNavigate: _navigate);
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
          BoxShadow(color: Color(0x06000000), blurRadius: 4,  offset: Offset(0, 1)),
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

          // ── Quick nav (role-based, right of logo) ──────
          const SizedBox(width: 20),
          Obx(() {
            final role = AuthController.to.currentRole;
            return _QuickNavBar(role: role, onNavigate: onNavigate);
          }),

          const Spacer(),

          // ── Clock ─────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
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

          const SizedBox(width: 20),

          // ── User info + action icons ───────────────────
          Obx(() {
            final user  = AuthController.to.user.value;
            final email = user?.email ?? '';
            final roleLabel = user?.role.name ?? '';
            final initial   = email.isNotEmpty ? email[0].toUpperCase() : 'U';

            return Row(
              children: [
                // User text
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

                // Avatar
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

                // Notifications
                _TopBarIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: () => onNavigate('notifications'),
                ),
                const SizedBox(width: 6),

                // Settings
                _TopBarIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => onNavigate('settings'),
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
// _TopBarIconButton
// ──────────────────────────────────────────────────────────────

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: _textSec, size: 18),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _QuickNavBar  – role-aware shortcut links next to logo
// ──────────────────────────────────────────────────────────────

class _QuickNavBar extends StatelessWidget {
  const _QuickNavBar({required this.role, required this.onNavigate});

  final AppRole? role;
  final void Function(String) onNavigate;

  List<Map<String, dynamic>> get _links {
    if (role == AppRole.admin) {
      return [
        {'label': 'Masalar',   'route': 'tables',    'icon': Icons.table_bar_rounded},
        {'label': 'Raporlar',  'route': 'reports',   'icon': Icons.bar_chart_rounded},
        {'label': 'Menü',      'route': 'menu',      'icon': Icons.restaurant_menu_rounded},
        {'label': 'Dashboard', 'route': 'dashboard', 'icon': Icons.dashboard_rounded},
      ];
    }
    return [
      {'label': 'Masalar', 'route': 'tables',  'icon': Icons.table_bar_rounded},
      {'label': 'Mutfak',  'route': 'kitchen', 'icon': Icons.kitchen_rounded},
      {'label': 'Vardiya', 'route': 'shifts',  'icon': Icons.schedule_rounded},
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (role == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: _links.map((link) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _QuickNavChip(
                label: link['label'] as String,
                icon:  link['icon']  as IconData,
                onTap: () => onNavigate(link['route'] as String),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _QuickNavChip extends StatefulWidget {
  const _QuickNavChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QuickNavChip> createState() => _QuickNavChipState();
}

class _QuickNavChipState extends State<_QuickNavChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? _orangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? _orange.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: _hovered ? _orange : _textSec),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _hovered ? _orange : _textSec,
                ),
              ),
            ],
          ),
        ),
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

      final today = DateTime.now();
      final todaySales = SalesHistoryService.to.sales.where((s) {
        final ts = DateTime.tryParse(s['date'] as String? ?? '');
        return ts != null &&
            ts.year == today.year &&
            ts.month == today.month &&
            ts.day == today.day;
      }).fold<double>(0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));

      return LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          return Column(children: [
            _StatCard(icon: Icons.table_bar_rounded, iconColor: const Color(0xFF5DADE2), label: 'Toplam Masa',   value: '$total'),
            const SizedBox(height: 12),
            _StatCard(icon: Icons.circle,            iconColor: const Color(0xFF52C97F), label: 'Dolu Masa',     value: '$occupied / $total'),
            const SizedBox(height: 12),
            _StatCard(icon: Icons.payments_rounded,  iconColor: _orange,                label: 'Bugünkü Satış', value: '₺${todaySales.toStringAsFixed(2)}'),
          ]);
        }
        return Row(children: [
          Expanded(child: _StatCard(icon: Icons.table_bar_rounded, iconColor: const Color(0xFF5DADE2), label: 'Toplam Masa',   value: '$total')),
          const SizedBox(width: 16),
          Expanded(child: _StatCard(icon: Icons.circle,            iconColor: const Color(0xFF52C97F), label: 'Dolu Masa',     value: '$occupied / $total')),
          const SizedBox(width: 16),
          Expanded(child: _StatCard(icon: Icons.payments_rounded,  iconColor: _orange,                label: 'Bugünkü Satış', value: '₺${todaySales.toStringAsFixed(2)}')),
        ]);
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
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x08000000), blurRadius: 4,  offset: Offset(0, 2)),
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
              Text(label, style: const TextStyle(fontSize: 12, color: _textSec)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _FeatureGrid  – 4-column icon-first layout
// ──────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.cards, required this.onNavigate});

  final List<Map<String, dynamic>> cards;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols    = w < 480 ? 2 : w < 720 ? 3 : 4;
      const spacing = 16.0;
      final itemW   = (w - spacing * (cols - 1)) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards.map((card) {
          return SizedBox(
            width: itemW,
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

// ──────────────────────────────────────────────────────────────
// _FeatureCard  – icon-centric, tap-anywhere, 4-col optimised
// ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.card, this.onTap});

  final Map<String, dynamic> card;
  final VoidCallback? onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_)   => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.card['primary'] as bool;
    final isActive  = widget.card['active']  as bool;
    final icon      = widget.card['icon']    as IconData;
    final color     = widget.card['color']   as Color;
    final title     = widget.card['title']   as String;
    final subtitle  = widget.card['subtitle'] as String;

    final bgColor     = isPrimary ? _orange : _card;
    final titleColor  = isPrimary ? Colors.white : _textPrimary;
    final subColor    = isPrimary ? Colors.white.withOpacity(0.75) : _textSec;
    final iconBg      = isPrimary ? Colors.white.withOpacity(0.22) : color.withOpacity(0.12);
    final iconColor   = isPrimary ? Colors.white : (isActive ? color : _textSec);

    return GestureDetector(
      onTap:       widget.onTap,
      onTapDown:   widget.onTap != null ? _onTapDown : null,
      onTapUp:     widget.onTap != null ? _onTapUp   : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isActive ? bgColor : _bg,
            borderRadius: BorderRadius.circular(24),
            border: isActive ? null : Border.all(color: _border),
            boxShadow: isActive
                ? isPrimary
                    ? const [
                        BoxShadow(color: Color(0x55F5A623), blurRadius: 20, offset: Offset(0, 8)),
                        BoxShadow(color: Color(0x22F5A623), blurRadius: 6,  offset: Offset(0, 2)),
                      ]
                    : const [
                        BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7)),
                        BoxShadow(color: Color(0x08000000), blurRadius: 5,  offset: Offset(0, 2)),
                      ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Big icon ────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 14),

              // ── Title ───────────────────────────────────
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isActive ? titleColor : _textSec,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),

              // ── Subtitle ────────────────────────────────
              Text(
                isActive ? subtitle : 'coming_soon'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? subColor : _textSec.withOpacity(0.6),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    final name = companyName.isNotEmpty ? companyName : 'Şirket Adınızı Giriniz';

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.support_agent_outlined, size: 13, color: _textSec),
          const SizedBox(width: 5),
          Text('customer_service'.tr, style: const TextStyle(fontSize: 11, color: _textSec)),
          const Spacer(),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          const Text('Adisyos v0.1 Beta · by Smartlogy', style: TextStyle(fontSize: 11, color: _textSec)),
        ],
      ),
    );
  }
}
