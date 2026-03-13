import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adisyos/views/notifications_view.dart';
import 'package:adisyos/views/tables_view.dart';
import 'package:adisyos/views/menu_management_view.dart';
import 'package:adisyos/views/reports_view.dart';
import 'package:adisyos/views/settings_view.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleGridItemTap(String route) {
    switch (route) {
      case 'tables':
        Get.to(() => const TablesView());
        break;
      case 'menu':
        Get.to(() => const MenuManagementView());
        break;
      case 'reports':
        Get.to(() => const ReportsView());
        break;
      case 'settings':
        Get.to(() => const SettingsView());
        break;
      case 'notifications':
        Get.to(() => const NotificationsView());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildMainGrid(context),
                ),
                const SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd MMMM EEEE', Get.locale?.languageCode)
                    .format(_currentTime),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormat('HH:mm:ss').format(_currentTime),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Flexible(
          flex: 2,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'adisyos',
                style: GoogleFonts.righteous(
                  fontSize: 32,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 2,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
        Flexible(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => Get.to(() => const NotificationsView()),
                icon: const Icon(Icons.notifications, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Get.to(() => const SettingsView()),
                icon: const Icon(Icons.settings, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainGrid(BuildContext context) {
    final items = [
      {
        'icon': Icons.table_bar,
        'title': 'tables'.tr,
        'route': 'tables',
        'active': true,
      },
      {
        'icon': Icons.restaurant_menu,
        'title': 'menu'.tr,
        'route': 'menu',
        'active': true,
      },
      {
        'icon': Icons.bar_chart,
        'title': 'reports'.tr,
        'route': 'reports',
        'active': true,
      },
      {
        'icon': Icons.people,
        'title': 'staff'.tr,
        'route': 'staff',
        'active': false,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossAxisCount = isWide ? 4 : 2;
        final spacing = isWide ? 32.0 : 16.0;
        final padding = isWide ? 32.0 : 16.0;

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: isWide ? 1.33 : 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildGridItem(
              context,
              icon: items[index]['icon'] as IconData,
              title: items[index]['title'] as String,
              route: items[index]['route'] as String,
              active: items[index]['active'] as bool,
              isWide: isWide,
            );
          },
        );
      },
    );
  }

  Widget _buildGridItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required bool active,
    required bool isWide,
  }) {
    return InkWell(
      onTap: active ? () => _handleGridItemTap(route) : null,
      borderRadius: BorderRadius.circular(isWide ? 32 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isWide ? 32 : 16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: isWide ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    size: isWide ? 64 : 32,
                  ),
                  SizedBox(height: isWide ? 24 : 12),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isWide ? 24 : 12),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: isWide ? 20 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (!active)
              Positioned(
                top: isWide ? 24 : 12,
                right: isWide ? 24 : 12,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 16 : 8,
                    vertical: isWide ? 8 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(isWide ? 20 : 12),
                  ),
                  child: Text(
                    'coming_soon'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWide ? 14 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FutureBuilder<String?>(
      future: _getCompanyName(),
      builder: (context, snapshot) {
        final companyName =
            (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : 'Şirket Adınızı Giriniz';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                'customer_service'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'Adisyos v0.1 (Beta) by Smartlogy',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(
                width: 120,
                child: Text(
                  companyName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('companyName');
  }
}
