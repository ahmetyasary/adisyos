import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/models/payment_type.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/themes/app_colors.dart';

Color get _reportCard => AppColors.card;
Color get _reportTextPrimary => AppColors.textPrimary;
Color get _reportTextSec => AppColors.textSec;
Color get _reportBorder => AppColors.border;
Color get _reportChip => AppColors.chipBg;

/// Ranked money rows (staff / table / etc.).
class ReportMoneyRankList extends StatelessWidget {
  const ReportMoneyRankList({
    super.key,
    required this.entries,
    required this.cs,
    this.accent = AppTheme.accentColor,
    this.valueSuffix,
  });

  final List<MapEntry<String, double>> entries;
  final String cs;
  final Color accent;
  final String? valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Veri yok', style: TextStyle(color: _reportTextSec)),
      );
    }
    final maxV = entries.first.value;
    return Column(
      children: entries.asMap().entries.map((e) {
        final rank = e.key + 1;
        final item = e.value;
        final fraction = maxV > 0 ? item.value / maxV : 0.0;
        final trailing = valueSuffix != null
            ? '${item.value.toInt()} $valueSuffix'
            : '$cs${item.value.toStringAsFixed(2)}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: rank == 1 ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _reportTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          trailing,
                          style: TextStyle(
                            color: valueSuffix != null
                                ? _reportTextSec
                                : accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: _reportBorder,
                      color: accent,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Flat sale row: time · table · total · payment · staff. Tap → items sheet.
class ReportSaleTile extends StatelessWidget {
  const ReportSaleTile({
    super.key,
    required this.sale,
    required this.cs,
    this.tableLabel,
  });

  final Map<String, dynamic> sale;
  final String cs;
  final String? tableLabel;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(sale['date'] as String);
    final table = tableLabel ?? (sale['tableName'] as String? ?? '—');
    final total = (sale['total'] as num).toDouble();
    final method = (sale['paymentMethod'] as String?) ?? 'cash';
    final staff = SalesHistoryService.staffLabel(sale['staffEmail'] as String?);
    final (icon, color) = paymentTypeVisual(method);
    final payLabel = SettingsService.to.paymentMethodLabel(method);

    return Material(
      color: _reportCard,
      child: InkWell(
        onTap: () => showReportSaleItemsSheet(sale, cs),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  DateFormat('HH:mm').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _reportTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _reportTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$staff · $payLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: _reportTextSec,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                '$cs${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: _reportTextSec),
            ],
          ),
        ),
      ),
    );
  }
}

void showReportSaleItemsSheet(Map<String, dynamic> sale, String cs) {
  final items = (sale['items'] as List).cast<Map<String, dynamic>>();
  final date = DateTime.parse(sale['date'] as String);
  final table = sale['tableName'] as String? ?? '—';
  final total = (sale['total'] as num).toDouble();

  Get.bottomSheet(
    Container(
      decoration: BoxDecoration(
        color: _reportCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _reportBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$table · ${DateFormat('HH:mm').format(date)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _reportTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              SalesHistoryService.staffLabel(sale['staffEmail'] as String?),
              style: TextStyle(fontSize: 13, color: _reportTextSec),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Text('Ürün yok', style: TextStyle(color: _reportTextSec))
            else
              ...items.map((item) {
                final qty = (item['quantity'] as num).toInt();
                final price = (item['price'] as num).toDouble();
                final name = item['name'] as String? ?? '—';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _reportChip,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qty×',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _reportTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _reportTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$cs${(price * qty).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _reportTextSec,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            Divider(height: 24, color: _reportBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _reportTextPrimary,
                  ),
                ),
                Text(
                  '$cs${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

/// Day row for monthly report.
class ReportDaySummaryTile extends StatelessWidget {
  const ReportDaySummaryTile({
    super.key,
    required this.date,
    required this.total,
    required this.count,
    required this.cs,
    required this.onTap,
  });

  final DateTime date;
  final double total;
  final int count;
  final String cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avg = count == 0 ? 0.0 : total / count;
    final label = DateFormat(
      'dd MMMM EEEE',
      Get.locale?.languageCode ?? 'tr',
    ).format(date);

    return Material(
      color: _reportCard,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _reportTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count adisyon · ort. $cs${avg.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _reportTextSec,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$cs${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: _reportTextSec),
            ],
          ),
        ),
      ),
    );
  }
}
