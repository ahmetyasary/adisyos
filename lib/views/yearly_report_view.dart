import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/settings_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

class YearlyReportView extends StatelessWidget {
  const YearlyReportView({super.key});

  static const List<String> _monthNamesTr = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  static const List<String> _monthNamesEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  List<String> get _monthNames {
    final lang = Get.locale?.languageCode ?? 'tr';
    return lang == 'tr' ? _monthNamesTr : _monthNamesEn;
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: 'yearly_report'.tr),
            Expanded(
              child: Obx(() {
                final cs = SettingsService.cs;
                final sales =
                    SalesHistoryService.to.getSalesForYear(year);
                final total =
                    SalesHistoryService.to.getTotalForSales(sales);
                final monthlyTotals =
                    SalesHistoryService.to.getMonthlyTotals(year);
                final topItems =
                    SalesHistoryService.to.getTopItems(sales, top: 5);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year label
                      Text(
                        '$year',
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
                              icon: Icons.trending_up_rounded,
                              label: 'Aylık Ort.',
                              value: sales.isEmpty
                                  ? '${cs}0.00'
                                  : '$cs${(total / 12).toStringAsFixed(2)}',
                              accent: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (sales.isEmpty)
                        _buildEmptyState()
                      else ...[
                        // Monthly line chart
                        _SectionTitle(
                            title: 'yearly_sales_title'.tr,
                            icon: Icons.show_chart_rounded,
                            accent: AppTheme.warningColor),
                        const SizedBox(height: 12),
                        _ChartCard(
                            child: _buildMonthlyChart(monthlyTotals, cs)),
                        const SizedBox(height: 24),

                        // Category pie chart + list
                        if (topItems.isNotEmpty) ...[
                          _SectionTitle(
                              title: 'top_items'.tr,
                              icon: Icons.pie_chart_rounded,
                              accent: AppTheme.warningColor),
                          const SizedBox(height: 12),
                          _ContentCard(
                            child: Column(
                              children: [
                                _buildCategoryChart(topItems),
                                const SizedBox(height: 16),
                                const Divider(color: _border, height: 1),
                                const SizedBox(height: 16),
                                _buildTopItemsList(topItems),
                              ],
                            ),
                          ),
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

  Widget _buildMonthlyChart(Map<int, double> monthlyTotals, String cs) {
    final values =
        List.generate(12, (i) => monthlyTotals[i + 1] ?? 0.0);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final spots =
        List.generate(12, (i) => FlSpot(i.toDouble(), values[i]));

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
                      style:
                          const TextStyle(fontSize: 9, color: _textSec),
                    ),
                  );
                },
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

  Widget _buildCategoryChart(List<MapEntry<String, double>> topItems) {
    final total = topItems.fold(0.0, (sum, e) => sum + e.value);
    final colors = [
      AppTheme.accentColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.infoColor,
    ];

    return Row(
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: PieChart(
            PieChartData(
              sections: topItems.asMap().entries.map((entry) {
                final pct = total > 0
                    ? entry.value.value / total * 100
                    : 0.0;
                return PieChartSectionData(
                  value: entry.value.value,
                  color: colors[entry.key % colors.length],
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: topItems.asMap().entries.map((entry) {
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value.key,
                        style: const TextStyle(
                            fontSize: 13, color: _textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value.value.toInt()}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopItemsList(List<MapEntry<String, double>> topItems) {
    final maxQty = topItems.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: AppTheme.warningColor
                      .withValues(alpha: rank == 1 ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.warningColor,
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
