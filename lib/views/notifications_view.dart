import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
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
        child: Obx(() {
          final recentSales = SalesHistoryService.to.getRecentSales(limit: 30);

          if (recentSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_notifications'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recentSales.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            itemBuilder: (context, index) {
              final sale = recentSales[index];
              return _buildNotificationItem(context, sale);
            },
          );
        }),
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, Map<String, dynamic> sale) {
    final date = DateTime.parse(sale['date'] as String);
    final now = DateTime.now();
    final diff = now.difference(date);

    String timeLabel;
    if (diff.inMinutes < 1) {
      timeLabel = 'Az önce';
    } else if (diff.inMinutes < 60) {
      timeLabel = '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      timeLabel = DateFormat('HH:mm').format(date);
    } else {
      timeLabel = DateFormat('dd MMM HH:mm',
              Get.locale?.languageCode ?? 'tr')
          .format(date);
    }

    final total = sale['total'] as double;
    final tableName = sale['tableName'] as String;
    final itemCount = (sale['items'] as List).length;
    final discount = (sale['discount'] ?? 0.0) as double;

    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payment,
              color: AppTheme.successColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'payment_notification'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Bugün',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$tableName · $itemCount ürün${discount > 0 ? ' · İndirimli' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
