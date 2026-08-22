import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:orderix/models/payment_type.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/report_excel_exporter.dart';
import 'package:orderix/views/report_breakdowns.dart';
import 'package:orderix/utils/app_haptics.dart';

/// Returns "Section · tableName" when a live table with that name has a section.
String _resolveTableLabel(String rawName) {
  final tables = TableService.to.tables;
  final match =
      tables.firstWhereOrNull((t) => (t['name'] as String) == rawName);
  if (match == null) return rawName;
  final sectionId = match['sectionId'] as String?;
  final sectionName = SectionService.to.nameById(sectionId);
  if (sectionName != null && sectionName.isNotEmpty) {
    return '$sectionName · $rawName';
  }
  return rawName;
}

// ── Apple-inspired design tokens ──────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);

class DailyReportView extends StatelessWidget {
  /// [inline] renders the report body only (no own Scaffold/header), for
  /// embedding as the detail pane of a tablet master-detail split view.
  /// [date] defaults to today — monthly drill-down passes a specific day.
  const DailyReportView({super.key, this.inline = false, this.date});

  final bool inline;
  final DateTime? date;

  DateTime get _day {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;

    final body = Obx(() {
      final cs = SettingsService.cs;
      final sales = SalesHistoryService.to.getSalesForDate(day);
      final total = SalesHistoryService.to.getTotalForSales(sales);
      final hourlyTotals = SalesHistoryService.to.getHourlyTotals(day);
      final topItems = SalesHistoryService.to.getTopItems(sales, top: 5);
      final staffTotals = SalesHistoryService.to.getStaffTotals(sales, top: 8);
      final tableTotals = SalesHistoryService.to.getTableTotals(sales, top: 8);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat(
                            'dd MMMM yyyy, EEEE',
                            Get.locale?.languageCode ?? 'tr')
                        .format(day),
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Builder(
                  builder: (btnCtx) => IconButton(
                    tooltip: 'Excel\'e aktar',
                    onPressed: () {
                      AppHaptics.selection();
                      ReportExcelExporter.exportDaily(
                        day,
                        shareOrigin:
                            ReportExcelExporter.shareOriginFrom(btnCtx),
                      );
                    },
                    icon: const Icon(CupertinoIcons.table,
                        size: 20, color: AppTheme.accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: 'total_sales'.tr,
                    value: '$cs${total.toStringAsFixed(2)}',
                    accent: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: CupertinoIcons.doc_text_fill,
                    label: 'sale_count'.tr,
                    value: '${sales.length}',
                    accent: AppTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: CupertinoIcons.arrow_up_right_circle_fill,
                    label: 'Ort. Adisyon',
                    value: sales.isEmpty
                        ? '${cs}0.00'
                        : '$cs${(total / sales.length).toStringAsFixed(2)}',
                    accent: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (sales.isEmpty)
              _buildEmptyState()
            else ...[
              // Hourly line chart
              _SectionTitle(
                  title: 'hourly_sales'.tr, icon: CupertinoIcons.clock_fill),
              const SizedBox(height: 12),
              _ChartCard(child: _buildHourlyLineChart(hourlyTotals, cs)),
              const SizedBox(height: 24),

              // Payment method breakdown
              _SectionTitle(
                  title: 'pay_breakdown'.tr,
                  icon: CupertinoIcons.chart_pie_fill),
              const SizedBox(height: 12),
              _ContentCard(
                  child: _buildPaymentBreakdown(
                      SalesHistoryService.to.getPaymentMethodTotals(sales),
                      total,
                      cs)),
              const SizedBox(height: 24),

              // Top items
              if (topItems.isNotEmpty) ...[
                _SectionTitle(
                    title: 'top_items'.tr, icon: CupertinoIcons.star_fill),
                const SizedBox(height: 12),
                _ContentCard(child: _buildTopItemsList(topItems)),
                const SizedBox(height: 24),
              ],

              if (staffTotals.isNotEmpty) ...[
                const _SectionTitle(
                    title: 'Personel satışları',
                    icon: CupertinoIcons.person_2_fill),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: staffTotals,
                    cs: cs,
                    accent: const Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (tableTotals.isNotEmpty) ...[
                const _SectionTitle(
                    title: 'Masa satışları',
                    icon: Icons.table_bar_rounded),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: tableTotals
                        .map((e) => MapEntry(_resolveTableLabel(e.key), e.value))
                        .toList(),
                    cs: cs,
                    accent: const Color(0xFFAF52DE),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Sale list — tap for line items
              const _SectionTitle(
                  title: 'Satışlar', icon: CupertinoIcons.list_bullet),
              const SizedBox(height: 12),
              _buildSalesList(sales, cs),
            ],
          ],
        ),
      );
    });

    if (inline) return body;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: 'daily_report'.tr),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales, String cs) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < sales.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _border),
            ReportSaleTile(
              sale: sales[i],
              cs: cs,
              tableLabel:
                  _resolveTableLabel(sales[i]['tableName'] as String? ?? ''),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hourly line chart (upgraded from bar chart) ───────────────
  Widget _buildHourlyLineChart(Map<int, double> hourlyTotals, String cs) {
    if (hourlyTotals.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('-')));
    }

    // Build a full 0-23 hour axis with 0 for empty hours
    final allHours = List.generate(24, (i) => i);
    final spots = allHours
        .map((h) => FlSpot(h.toDouble(), hourlyTotals[h] ?? 0))
        .toList();
    final maxY = hourlyTotals.values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.accentColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                  radius: spot.y > 0 ? 4 : 0,
                  color: AppTheme.accentColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.22),
                    AppTheme.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: maxY * 1.25,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                if (s.y == 0) return null;
                return LineTooltipItem(
                  '${s.x.toInt()}:00\n$cs${s.y.toStringAsFixed(0)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) => Text(
                  '$cs${value.toInt()}',
                  style: const TextStyle(fontSize: 9, color: _textSec),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt();
                  return Text(
                    '$h:00',
                    style: const TextStyle(fontSize: 9, color: _textSec),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _border, strokeWidth: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown(
      Map<String, double> totals, double grandTotal, String cs) {
    final configured = SettingsService.to.paymentTypes.toList();
    final keys = <String>[
      ...configured.map((t) => t.id),
      ...totals.keys.where((k) => !configured.any((t) => t.id == k)),
    ];
    return Column(
      children: keys.map((key) {
        final amount = totals[key] ?? 0.0;
        final fraction = grandTotal > 0 ? amount / grandTotal : 0.0;
        final (icon, color) = paymentTypeVisual(key);
        final label = SettingsService.to.paymentMethodLabel(key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        Text('$cs${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: _border,
                      color: color,
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

  Widget _buildTopItemsList(List<MapEntry<String, double>> topItems) {
    final maxQty = topItems.first.value;
    return Column(
      children: topItems.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;
        final fraction = maxQty > 0 ? item.value / maxQty : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor
                      .withValues(alpha: rank == 1 ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.accentColor,
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
                        Text(item.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _textPrimary)),
                        Text('${item.value.toInt()} adet',
                            style:
                                const TextStyle(color: _textSec, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: _border,
                      color: AppTheme.accentColor,
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

  Widget _buildEmptyState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _border,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.chart_bar_alt_fill,
                  size: 48, color: _textSec),
            ),
            const SizedBox(height: 16),
            Text(
              'no_sales_today'.tr,
              style: const TextStyle(color: _textSec, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.chevron_back,
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
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _textSec, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}
