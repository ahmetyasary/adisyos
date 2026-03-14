import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Design tokens ──────────────────────────────────────────
const _bg          = Color(0xFFF5F6FA);
const _card        = Colors.white;
const _textPrimary = Color(0xFF1A1A2E);
const _textSec     = Color(0xFF9B9B9B);
const _border      = Color(0xFFEEEEEE);

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: 'notifications'.tr),
            Expanded(
              child: Obx(() {
                final recentSales =
                    SalesHistoryService.to.getRecentSales(limit: 30);

                if (recentSales.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _textSec.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: _textSec,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'no_notifications'.tr,
                          style: const TextStyle(
                            color: _textSec,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: recentSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _NotificationCard(sale: recentSales[index]);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PageHeader ────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _card,
        border: const Border(bottom: BorderSide(color: _border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _textPrimary),
            onPressed: () => Get.back(),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── _NotificationCard ──────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.sale});
  final Map<String, dynamic> sale;

  @override
  Widget build(BuildContext context) {
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
      timeLabel = DateFormat(
        'dd MMM HH:mm',
        Get.locale?.languageCode ?? 'tr',
      ).format(date);
    }

    final total = sale['total'] as double;
    final tableName = sale['tableName'] as String;
    final itemCount = (sale['items'] as List).length;
    final discount = (sale['discount'] ?? 0.0) as double;

    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payment_rounded,
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
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Bugün',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$tableName · $itemCount ürün${discount > 0 ? ' · İndirimli' : ''}',
                  style: const TextStyle(color: _textSec, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: const TextStyle(color: _textSec, fontSize: 11),
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
