import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

class MonthlyReportView extends StatelessWidget {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: 'monthly_report'.tr),
            Expanded(
              child: Obx(() {
                final cs = SettingsService.cs;
                final sales = SalesHistoryService.to
                    .getSalesForMonth(now.year, now.month);
                final total =
                    SalesHistoryService.to.getTotalForSales(sales);
                final dailyTotals = SalesHistoryService.to
                    .getDailyTotals(now.year, now.month);
                final topItems =
                    SalesHistoryService.to.getTopItems(sales, top: 5);
                final monthName = DateFormat(
                        'MMMM yyyy', Get.locale?.languageCode ?? 'tr')
                    .format(now);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month label
                      Text(
                        monthName,
                        style: const TextStyle(
                          color: _textSec,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.attach_money_rounded,
                              label: 'total_sales'.tr,
                              value: '$cs${total.toStringAsFixed(2)}',
                              accent: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.receipt_long_rounded,
                              label: 'sale_count'.tr,
                              value: '${sales.length}',
                              accent: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'Aktif Gün',
                              value: '${dailyTotals.length}',
                              accent: _orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (sales.isEmpty)
                        _buildEmptyState()
                      else ...[
                        // Daily bar chart
                        _SectionTitle(
                            title: 'monthly_sales_title'.tr,
                            icon: Icons.bar_chart_rounded,
                            accent: _orange),
                        const SizedBox(height: 12),
                        _ChartCard(
                            child: _buildDailyChart(dailyTotals, now, cs)),
                        const SizedBox(height: 24),

                        // Top items
                        if (topItems.isNotEmpty) ...[
                          _SectionTitle(
                              title: 'top_items'.tr,
                              icon: Icons.star_rounded,
                              accent: _orange),
                          const SizedBox(height: 12),
                          _ContentCard(
                              child: _buildTopItemsList(topItems)),
                        ],
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(Map<int, double> dailyTotals, DateTime now, String cs) {
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
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5)),
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
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  color: _orange.withValues(
                      alpha: rank == 1 ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _orange,
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
                            style: const TextStyle(
                                color: _textSec, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: _border,
                      color: AppTheme.successColor,
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
              child: const Icon(Icons.bar_chart_rounded,
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
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, 0.28)!, accent],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.28), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
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
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
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
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}
