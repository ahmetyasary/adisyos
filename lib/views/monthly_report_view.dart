import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/services/report_excel_exporter.dart';
import 'package:orderix/views/daily_report_view.dart';
import 'package:orderix/views/report_breakdowns.dart';
import 'package:orderix/utils/app_haptics.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);

class MonthlyReportView extends StatelessWidget {
  /// [inline] renders the report body only (no own Scaffold/header), for
  /// embedding as the detail pane of a tablet master-detail split view.
  /// [year]/[month] default to the current month (yearly drill-down overrides).
  const MonthlyReportView({
    super.key,
    this.inline = false,
    this.year,
    this.month,
  });

  final bool inline;
  final int? year;
  final int? month;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final focus = DateTime(y, m);

    final body = Obx(() {
      final cs = SettingsService.cs;
      final sales = SalesHistoryService.to.getSalesForMonth(y, m);
      final total = SalesHistoryService.to.getTotalForSales(sales);
      final dailyTotals = SalesHistoryService.to.getDailyTotals(y, m);
      final daySummaries = SalesHistoryService.to.getDailySummaries(y, m);
      final topItems = SalesHistoryService.to.getTopItems(sales, top: 5);
      final staffTotals = SalesHistoryService.to.getStaffTotals(sales, top: 8);
      final tableTotals = SalesHistoryService.to.getTableTotals(sales, top: 8);
      final payTotals = SalesHistoryService.to.getPaymentMethodTotals(sales);
      final payEntries = payTotals.entries
          .map((e) => MapEntry(
                SettingsService.to.paymentMethodLabel(e.key),
                e.value,
              ))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final monthName =
          DateFormat('MMMM yyyy', Get.locale?.languageCode ?? 'tr')
              .format(focus);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    monthName,
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
                      ReportExcelExporter.exportMonthly(
                        y,
                        m,
                        shareOrigin:
                            ReportExcelExporter.shareOriginFrom(btnCtx),
                      );
                    },
                    icon: const Icon(CupertinoIcons.table,
                        size: 20, color: _orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                    accent: _orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (sales.isEmpty)
              _buildEmptyState()
            else ...[
              _SectionTitle(
                  title: 'monthly_sales_title'.tr,
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  accent: _orange),
              const SizedBox(height: 12),
              _ChartCard(child: _buildDailyChart(dailyTotals, focus, cs)),
              const SizedBox(height: 24),

              if (payEntries.isNotEmpty) ...[
                _SectionTitle(
                    title: 'pay_breakdown'.tr,
                    icon: CupertinoIcons.chart_pie_fill,
                    accent: _orange),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: payEntries,
                    cs: cs,
                    accent: _orange,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (topItems.isNotEmpty) ...[
                _SectionTitle(
                    title: 'top_items'.tr,
                    icon: CupertinoIcons.star_fill,
                    accent: _orange),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: topItems,
                    cs: cs,
                    accent: _orange,
                    valueSuffix: 'adet',
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (staffTotals.isNotEmpty) ...[
                const _SectionTitle(
                    title: 'Personel satışları',
                    icon: CupertinoIcons.person_2_fill,
                    accent: _orange),
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
                    icon: Icons.table_bar_rounded,
                    accent: _orange),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: tableTotals,
                    cs: cs,
                    accent: const Color(0xFFAF52DE),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const _SectionTitle(
                  title: 'Günlük özet',
                  icon: CupertinoIcons.calendar,
                  accent: _orange),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.fromBorderSide(
                      BorderSide(color: _border, width: 1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < daySummaries.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _border),
                      ReportDaySummaryTile(
                        date: daySummaries[i]['date'] as DateTime,
                        total: daySummaries[i]['total'] as double,
                        count: daySummaries[i]['count'] as int,
                        cs: cs,
                        onTap: () => Get.to(
                          () => DailyReportView(
                            date: daySummaries[i]['date'] as DateTime,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
            _Header(title: 'monthly_report'.tr),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(
      Map<int, double> dailyTotals, DateTime now, String cs) {
    if (dailyTotals.isEmpty) {
      return const SizedBox(
          height: 220, child: Center(child: Text('Veri yok')));
    }

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final maxY = dailyTotals.values.reduce((a, b) => a > b ? a : b);

    final barGroups = List.generate(daysInMonth, (i) {
      final day = i + 1;
      final val = dailyTotals[day] ?? 0.0;
      final hasData = val > 0;
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: val,
            gradient: hasData
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      _orange.withValues(alpha: 0.70),
                      _orange,
                    ],
                  )
                : null,
            color: hasData ? null : _border,
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    });

    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (rod.toY == 0) return null;
                return BarTooltipItem(
                  '${group.x}. Gün\n$cs${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                );
              },
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
                interval: 5,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 9, color: _textSec),
                ),
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
          barGroups: barGroups,
        ),
      ),
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
              'no_sales'.tr,
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
  const _SectionTitle(
      {required this.title, required this.icon, required this.accent});
  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent, size: 16),
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
