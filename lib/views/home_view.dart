import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adisyos/views/notifications_view.dart';
import 'package:adisyos/views/tables_view.dart';
import 'package:adisyos/views/menu_management_view.dart';
import 'package:adisyos/views/reports_view.dart';
import 'dart:async';

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
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleGridItemTap(String title) {
    switch (title) {
      case 'tables':
        Get.to(() => const TablesView());
        break;
      case 'menu':
        Get.to(() => const MenuManagementView());
        break;
      case 'reports':
        Get.to(() => const ReportsView());
        break;
      // Diğer sayfalar için case'ler buraya eklenecek
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd MMMM EEEE', Get.locale?.languageCode)
                    .format(_currentTime),
                style: const TextStyle(color: Colors.white70),
              ),
              Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(_currentTime),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(WeatherIcons.day_sunny, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentTime.hour > 12 ? (_currentTime.hour - 12) * 2 : _currentTime.hour * 2}°',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              'adisyos',
              style: GoogleFonts.righteous(
                fontSize: 32,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.wifi, color: Colors.green, size: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    const Icon(Icons.computer, color: Colors.green, size: 16),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => Get.to(() => const NotificationsView()),
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainGrid(BuildContext context) {
    final items = [
      {'icon': Icons.table_bar, 'title': 'tables'.tr, 'route': 'tables'},
      {
        'icon': Icons.shopping_cart,
        'title': 'quick_sale'.tr,
        'route': 'quick_sale'
      },
      {
        'icon': Icons.delivery_dining,
        'title': 'packages'.tr,
        'route': 'packages'
      },
      {
        'icon': Icons.shopping_bag,
        'title': 'online_orders'.tr,
        'route': 'online_orders'
      },
      {'icon': Icons.restaurant_menu, 'title': 'menu'.tr, 'route': 'menu'},
      {'icon': Icons.category, 'title': 'products'.tr, 'route': 'products'},
      {'icon': Icons.people, 'title': 'staff'.tr, 'route': 'staff'},
      {'icon': Icons.bar_chart, 'title': 'reports'.tr, 'route': 'reports'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Web platformu için özel düzenleme
        if (constraints.maxWidth > 800) {
          const crossAxisCount = 4;
          final cardWidth =
              (constraints.maxWidth - (32 * (crossAxisCount + 1))) /
                  crossAxisCount;
          final cardHeight = cardWidth * 0.75;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 32),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 32,
                mainAxisSpacing: 32,
                childAspectRatio: cardWidth / cardHeight,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildGridItem(
                  context,
                  icon: items[index]['icon'] as IconData,
                  title: items[index]['title'] as String,
                  route: items[index]['route'] as String,
                  isWeb: true,
                );
              },
            ),
          );
        }

        // Mobil görünüm için varsayılan düzen
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildGridItem(
              context,
              icon: items[index]['icon'] as IconData,
              title: items[index]['title'] as String,
              route: items[index]['route'] as String,
              isWeb: false,
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
    required bool isWeb,
  }) {
    final bool showComingSoon =
        route != 'tables' && route != 'menu' && route != 'reports';

    return InkWell(
      onTap: showComingSoon ? null : () => _handleGridItemTap(route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isWeb ? 32 : 16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: isWeb ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: showComingSoon
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    size: isWeb ? 64 : 32,
                  ),
                  SizedBox(height: isWeb ? 24 : 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 12),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: showComingSoon
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white,
                        fontSize: isWeb ? 20 : 14,
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
            if (showComingSoon)
              Positioned(
                top: isWeb ? 24 : 12,
                right: isWeb ? 24 : 12,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 16 : 8,
                    vertical: isWeb ? 8 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(isWeb ? 20 : 12),
                  ),
                  child: Text(
                    'Yakında',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 14 : 10,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'customer_service'.tr,
          style: const TextStyle(color: Colors.white70),
        ),
        const Text(
          'Smartlogy POS 1.0 Standart Edition',
          style: TextStyle(color: Colors.white70),
        ),
        Text(
          '23 Society',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }
}
