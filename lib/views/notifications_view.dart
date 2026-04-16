import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
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
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: SizedBox(
        height: 52,
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
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppTheme.successColor, Colors.white, 0.28)!,
                  AppTheme.successColor,
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successColor.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.payment_rounded,
              color: Colors.white,
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
                    Obx(() => Text(
                      '${SettingsService.cs}${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
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
