import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/services/settings_service.dart';
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

// ── Apple-inspired design tokens ──────────────────────────────
const _bg             = Color(0xFFF2F2F7); // iOS system grouped background
const _card           = Colors.white;
const _orange         = Color(0xFFFF9500); // iOS system orange (brand)
const _orangeLight    = Color(0xFFFFF4E0);
const _labelPrimary   = Color(0xFF1C1C1E); // iOS primary label
const _labelSecondary = Color(0xFF8E8E93); // iOS secondary label
const _separator      = Color(0xFFE5E5EA); // iOS separator

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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
        'color':   const Color(0xFFFF9500), // iOS Orange
        'route':   'tables',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'reports'.tr,
        'subtitle':'Günlük, aylık ve yıllık raporlar',
        'icon':    Icons.bar_chart_rounded,
        'color':   const Color(0xFF007AFF), // iOS Blue
        'route':   'reports',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'menu'.tr,
        'subtitle':'Ürün ve kategori yönetimi',
        'icon':    Icons.restaurant_menu_rounded,
        'color':   const Color(0xFF34C759), // iOS Green
        'route':   'menu',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Mutfak',
        'subtitle':'Sipariş durumunu takip et',
        'icon':    Icons.local_fire_department_rounded,
        'color':   const Color(0xFFFF3B30), // iOS Red
        'route':   'kitchen',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'Stoklar',
        'subtitle':'Ürün stok yönetimi',
        'icon':    Icons.inventory_2_rounded,
        'color':   const Color(0xFFAF52DE), // iOS Purple
        'route':   'inventory',
        'active':  true,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Personel',
        'subtitle':'Performans ve puantaj',
        'icon':    Icons.people_rounded,
        'color':   const Color(0xFF5856D6), // iOS Indigo
        'route':   'staff_report',
        'active':  true,
        'hidden':  false,
        'primary': false,
        'roles':   [AppRole.admin],
      },
      {
        'title':   'Vardiya',
        'subtitle':'Giriş/çıkış ve mola takibi',
        'icon':    Icons.schedule_rounded,
        'color':   const Color(0xFF30B0C7), // Teal
        'route':   'shifts',
        'active':  true,
        'hidden':  true,
        'primary': false,
        'roles':   [AppRole.admin, AppRole.staff],
      },
      {
        'title':   'Dashboard',
        'subtitle':'Canlı doluluk ve satış takibi',
        'icon':    Icons.dashboard_rounded,
        'color':   const Color(0xFF3A3A3C), // Dark charcoal
        'route':   'dashboard',
        'active':  true,
        'hidden':  false,
        'primary': false,
        'roles':   [AppRole.admin],
      },
    ];

    if (role == null) return [];
    return all.where((c) =>
      (c['roles'] as List<AppRole>).contains(role) &&
      (c['hidden'] as bool? ?? false) == false,
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              currentTime: _currentTime,
              onNavigate: _navigate,
            ),
            Expanded(
              child: Obx(() {
                final role = AuthController.to.currentRole;
                final cards = _featureCards(role);
                return _MainContent(cards: cards, onNavigate: _navigate);
              }),
            ),
            Obx(() => _Footer(companyName: SettingsService.to.companyName.value)),
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
    required this.onNavigate,
  });

  final DateTime currentTime;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 20, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // ── Brand ─────────────────────────────────────
          Text(
            'adisyos',
            style: GoogleFonts.righteous(
              fontSize: 22,
              color: _orange,
              letterSpacing: 1.5,
            ),
          ),

          const Spacer(),

          // ── Clock ─────────────────────────────────────
          Text(
            DateFormat('HH:mm').format(currentTime),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _labelPrimary,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(width: 12),

          // ── Action icons ───────────────────────────────
          _TopBarIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => onNavigate('notifications'),
          ),
          const SizedBox(width: 6),
          _TopBarIconButton(
            icon: Icons.settings_outlined,
            onTap: () => onNavigate('settings'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _TopBarIconButton
// ──────────────────────────────────────────────────────────────

class _TopBarIconButton extends StatefulWidget {
  const _TopBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered ? _separator : _bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            color: _hovered ? _labelPrimary : _labelSecondary,
            size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Genel Bakış'),
          const SizedBox(height: 12),
          _StatsRow(),
          const SizedBox(height: 28),
          const _SectionHeader(label: 'Modüller'),
          const SizedBox(height: 12),
          _FeatureGrid(cards: cards, onNavigate: onNavigate),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _SectionHeader
// ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _labelSecondary,
        letterSpacing: 0.7,
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
      final today = DateTime.now();
      final todaySales = SalesHistoryService.to.sales.where((s) {
        final ts = DateTime.tryParse(s['date'] as String? ?? '');
        return ts != null &&
            ts.year  == today.year  &&
            ts.month == today.month &&
            ts.day   == today.day;
      }).fold<double>(0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));

      return _SalesBanner(amount: todaySales);
    });
  }
}

class _SalesBanner extends StatelessWidget {
  const _SalesBanner({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Gradient icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(_orange, Colors.white, 0.25)!,
                  _orange,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40FF9500),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 18),

          // Label + amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bugünkü Satış',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _labelSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₺${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _labelPrimary,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Subtle date label on the right
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bugün',
                style: TextStyle(
                  fontSize: 11,
                  color: _labelSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM, EEE', Get.locale?.languageCode).format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _labelPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Gradient icon container
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(iconColor, Colors.white, 0.25)!,
                  iconColor,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _labelSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _labelPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
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
      final w       = constraints.maxWidth;
      final cols    = w < 480 ? 2 : w < 720 ? 3 : 4;
      const spacing = 14.0;
      final itemW   = (w - spacing * (cols - 1)) / cols;

      return Obx(() {
        final tables   = TableService.to.tables;
        final occupied = tables.where((t) => t['isOccupied'] == true).length;
        final total    = tables.length;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            final occupancyLabel = card['route'] == 'tables' && total > 0
                ? '$occupied/$total'
                : null;
            return SizedBox(
              width: itemW,
              child: _FeatureCard(
                card: card,
                occupancyLabel: occupancyLabel,
                onTap: (card['active'] as bool)
                    ? () => onNavigate(card['route'] as String)
                    : null,
              ),
            );
          }).toList(),
        );
      });
    });
  }
}

// ──────────────────────────────────────────────────────────────
// _FeatureCard
// ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.card, this.onTap, this.occupancyLabel});

  final Map<String, dynamic> card;
  final VoidCallback? onTap;
  final String? occupancyLabel;

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

    // iOS app-icon style gradient for active cards
    final iconGradient = isActive
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPrimary
                ? [const Color(0xFFFFB340), _orange]
                : [Color.lerp(color, Colors.white, 0.28)!, color],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5E5EA), Color(0xFFD1D1D6)],
          );

    final cardBg    = isPrimary ? _orange : _card;
    final titleColor  = isPrimary ? Colors.white : _labelPrimary;
    final subColor    = isPrimary ? Colors.white.withOpacity(0.75) : _labelSecondary;

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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isActive ? cardBg : const Color(0xFFF9F9FB),
            borderRadius: BorderRadius.circular(22),
            border: isActive
                ? null
                : Border.all(color: _separator, width: 0.5),
            boxShadow: isActive
                ? isPrimary
                    ? const [
                        BoxShadow(color: Color(0x50FF9500), blurRadius: 22, offset: Offset(0, 8)),
                        BoxShadow(color: Color(0x20FF9500), blurRadius: 6,  offset: Offset(0, 2)),
                      ]
                    : const [
                        BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 6)),
                        BoxShadow(color: Color(0x07000000), blurRadius: 5,  offset: Offset(0, 2)),
                      ]
                : null,
          ),
          child: Stack(
            children: [
              const SizedBox(width: double.infinity),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── App-icon style container ───────────────
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: iconGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.30),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(icon, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 14),

                  // ── Title ─────────────────────────────────
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive ? titleColor : _labelSecondary,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Subtitle ──────────────────────────────
                  Text(
                    isActive ? subtitle : 'coming_soon'.tr,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isActive
                          ? subColor
                          : _labelSecondary.withOpacity(0.55),
                      height: 1.35,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // ── Occupancy badge — top-right ───────────────
              if (widget.occupancyLabel != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 7, color: Color(0xFF34C759)),
                        const SizedBox(width: 5),
                        Text(
                          widget.occupancyLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF34C759),
                          ),
                        ),
                      ],
                    ),
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
// _Footer
// ──────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.companyName});
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final name = companyName.isNotEmpty ? companyName : 'Şirket Adınızı Giriniz';

    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _separator, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _labelPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent_outlined, size: 12, color: _labelSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'customer_service'.tr,
                    style: const TextStyle(fontSize: 10, color: _labelSecondary),
                  ),
                ],
              ),
              const Text(
                '  ·  ',
                style: TextStyle(fontSize: 10, color: _labelSecondary),
              ),
              const Text(
                'Adisyos v0.1 Beta · by Smartlogy',
                style: TextStyle(fontSize: 10, color: _labelSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
