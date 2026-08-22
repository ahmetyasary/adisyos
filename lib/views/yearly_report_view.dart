import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/services/report_excel_exporter.dart';
import 'package:orderix/views/monthly_report_view.dart';
import 'package:orderix/views/report_breakdowns.dart';
import 'package:orderix/utils/app_haptics.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);
const _orange = Color(0xFFFF9500);

class YearlyReportView extends StatelessWidget {
  /// [inline] renders the report body only (no own Scaffold/header), for
  /// embedding as the detail pane of a tablet master-detail split view.
  const YearlyReportView({super.key, this.inline = false, this.year});

  final bool inline;
  final int? year;

  static const List<String> _monthNamesTr = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  static const List<String> _monthNamesEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<String> get _monthNames {
    final lang = Get.locale?.languageCode ?? 'tr';
    return lang == 'tr' ? _monthNamesTr : _monthNamesEn;
  }

  @override
  Widget build(BuildContext context) {
    final y = year ?? DateTime.now().year;

    final body = Obx(() {
      final cs = SettingsService.cs;
      final sales = SalesHistoryService.to.getSalesForYear(y);
      final total = SalesHistoryService.to.getTotalForSales(sales);
      final monthlyTotals = SalesHistoryService.to.getMonthlyTotals(y);
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
      final activeMonths =
          monthlyTotals.values.where((v) => v > 0).length.clamp(1, 12);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$y',
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
                      ReportExcelExporter.exportYearly(
                        y,
                        shareOrigin:
                            ReportExcelExporter.shareOriginFrom(btnCtx),
                      );
                    },
                    icon: const Icon(CupertinoIcons.table,
                        size: 20, color: AppTheme.warningColor),
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
                    accent: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (sales.isEmpty)
              _buildEmptyState()
            else ...[
              _SectionTitle(
                  title: 'yearly_sales_title'.tr,
                  icon: CupertinoIcons.graph_circle_fill,
                  accent: AppTheme.warningColor),
              const SizedBox(height: 12),
              _ChartCard(child: _buildMonthlyChart(monthlyTotals, cs)),
              const SizedBox(height: 8),
              Text(
                'Aylık ort. ciro: $cs${(total / activeMonths).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: _textSec),
              ),
              const SizedBox(height: 24),

              // Tappable month list (months with sales)
              const _SectionTitle(
                  title: 'Aylar',
                  icon: CupertinoIcons.calendar,
                  accent: AppTheme.warningColor),
              const SizedBox(height: 12),
              _buildMonthList(y, monthlyTotals, cs),
              const SizedBox(height: 24),

              if (payEntries.isNotEmpty) ...[
                _SectionTitle(
                    title: 'pay_breakdown'.tr,
                    icon: CupertinoIcons.chart_pie_fill,
                    accent: AppTheme.warningColor),
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
                    accent: AppTheme.warningColor),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: topItems,
                    cs: cs,
                    accent: AppTheme.warningColor,
                    valueSuffix: 'adet',
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (staffTotals.isNotEmpty) ...[
                const _SectionTitle(
                    title: 'Personel satışları',
                    icon: CupertinoIcons.person_2_fill,
                    accent: AppTheme.warningColor),
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
                    accent: AppTheme.warningColor),
                const SizedBox(height: 12),
                _ContentCard(
                  child: ReportMoneyRankList(
                    entries: tableTotals,
                    cs: cs,
                    accent: const Color(0xFFAF52DE),
                  ),
                ),
              ],
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
            _Header(title: 'yearly_report'.tr),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthList(
      int year, Map<int, double> monthlyTotals, String cs) {
    final rows = <Widget>[];
    for (var m = 12; m >= 1; m--) {
      final total = monthlyTotals[m] ?? 0.0;
      if (total <= 0) continue;
      final monthSales =
          SalesHistoryService.to.getSalesForMonth(year, m);
      final count = monthSales.length;
      final name = _monthNames[m - 1];
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, color: _border));
      }
      rows.add(
        Material(
          color: _card,
          child: InkWell(
            onTap: () => Get.to(
              () => MonthlyReportView(year: year, month: m),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name $year',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count adisyon',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSec,
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
                  const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: _textSec),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _buildMonthlyChart(Map<int, double> monthlyTotals, String cs) {
    final values = List.generate(12, (i) => monthlyTotals[i + 1] ?? 0.0);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final spots = List.generate(12, (i) => FlSpot(i.toDouble(), values[i]));

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              gradient: const LinearGradient(
                colors: [AppTheme.warningColor, Color(0xFFFF6B00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) {
                  if (spot.y == 0) {
                    return FlDotCirclePainter(
                      radius: 2,
                      color: _border,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppTheme.warningColor,
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.warningColor.withValues(alpha: 0.20),
                    AppTheme.warningColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: maxY > 0 ? maxY * 1.25 : 100,
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
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= 12) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _monthNames[idx],
                      style: const TextStyle(fontSize: 9, color: _textSec),
                    ),
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
            horizontalInterval: maxY > 0 ? maxY / 4 : 25,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _border, strokeWidth: 1),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  if (spot.y == 0) return null;
                  return LineTooltipItem(
                    '${_monthNames[spot.x.toInt()]}\n$cs${spot.y.toStringAsFixed(0)}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                }).toList();
              },
            ),
          ),
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
