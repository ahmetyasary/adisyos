import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Apple-inspired design tokens ──────────────────────────────
Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.borderSoft;

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _PageHeader(title: 'notifications'.tr, embedded: embedded),
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
                          child: Icon(
                            CupertinoIcons.bell,
                            size: 48,
                            color: _textSec,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'no_notifications'.tr,
                          style: TextStyle(
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
  const _PageHeader({required this.title, this.embedded = false});
  final String title;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ShellLeading(embedded: embedded, color: _textPrimary),
            Text(
              title,
              style: TextStyle(
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

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.money_dollar_circle_fill,
            color: AppTheme.successColor,
            size: 30,
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
                      style: TextStyle(
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
                  style: TextStyle(color: _textSec, fontSize: 12),
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
                      style: TextStyle(color: _textSec, fontSize: 11),
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
