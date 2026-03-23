import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

class DailyReportView extends StatelessWidget {
  const DailyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'daily_report'.tr),
            Expanded(
              child: Obx(() {
                final sales = SalesHistoryService.to.getSalesForDate(today);
                final total = SalesHistoryService.to.getTotalForSales(sales);
                final hourlyTotals =
                    SalesHistoryService.to.getHourlyTotals(today);
                final topItems =
                    SalesHistoryService.to.getTopItems(sales, top: 5);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date label
                      Text(
                        DateFormat('dd MMMM yyyy, EEEE',
                                Get.locale?.languageCode ?? 'tr')
                            .format(today),
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
                              value: '₺${total.toStringAsFixed(2)}',
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
                              label: 'Ort. Sipariş',
                              value: sales.isEmpty
                                  ? '₺0.00'
                                  : '₺${(total / sales.length).toStringAsFixed(2)}',
                              accent: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (sales.isEmpty)
                        _buildEmptyState()
                      else ...[
                        // Hourly chart
                        _SectionTitle(
                            title: 'hourly_sales'.tr,
                            icon: Icons.access_time_rounded),
                        const SizedBox(height: 12),
                        _ChartCard(
                            child: _buildHourlyChart(hourlyTotals)),
                        const SizedBox(height: 24),

                        // Payment method breakdown
                        _SectionTitle(
                            title: 'pay_breakdown'.tr,
                            icon: Icons.pie_chart_rounded),
                        const SizedBox(height: 12),
                        _ContentCard(
                            child: _buildPaymentBreakdown(
                                SalesHistoryService.to
                                    .getPaymentMethodTotals(sales),
                                total)),
                        const SizedBox(height: 24),

                        // Top items
                        if (topItems.isNotEmpty) ...[
                          _SectionTitle(
                              title: 'top_items'.tr,
                              icon: Icons.star_rounded),
                          const SizedBox(height: 12),
                          _ContentCard(
                              child: _buildTopItemsList(topItems)),
                          const SizedBox(height: 24),
                        ],

                        // Recent transactions
                        _SectionTitle(
                            title: 'recent_activity'.tr,
                            icon: Icons.list_alt_rounded),
                        const SizedBox(height: 12),
                        _buildTransactionsList(sales),
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

  Widget _buildHourlyChart(Map<int, double> hourlyTotals) {
    if (hourlyTotals.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text('-')));
    }

    final maxY = hourlyTotals.values.reduce((a, b) => a > b ? a : b);
    final barGroups = hourlyTotals.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppTheme.accentColor,
            width: 16,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${group.x}:00\n₺${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  '₺${value.toInt()}',
                  style:
                      const TextStyle(fontSize: 10, color: _textSec),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}:00',
                  style:
                      const TextStyle(fontSize: 10, color: _textSec),
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
            getDrawingHorizontalLine: (_) => FlLine(
              color: _border,
              strokeWidth: 1,
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown(
      Map<String, double> totals, double grandTotal) {
    final methods = [
      {'key': 'cash', 'label': 'pay_cash', 'icon': Icons.payments_rounded, 'color': const Color(0xFF52C97F)},
      {'key': 'card', 'label': 'pay_card', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF5DADE2)},
      {'key': 'transfer', 'label': 'pay_transfer', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFFAB84F5)},
    ];
    return Column(
      children: methods.map((m) {
        final amount = totals[m['key'] as String] ?? 0.0;
        final fraction = grandTotal > 0 ? amount / grandTotal : 0.0;
        final color = m['color'] as Color;
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
                child: Icon(m['icon'] as IconData, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((m['label'] as String).tr,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        Text('₺${amount.toStringAsFixed(2)}',
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

  Widget _buildTransactionsList(List<Map<String, dynamic>> sales) {
    final recent = sales.reversed.take(10).toList();
    return Column(
      children: recent.map((sale) {
        final date = DateTime.parse(sale['date'] as String);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            boxShadow: [
              BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 3)),
              BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: AppTheme.successColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale['tableName'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        '${(sale['items'] as List).length} ürün · ${DateFormat('HH:mm').format(date)}',
                        style:
                            const TextStyle(color: _textSec, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '₺${(sale['total'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                  fontSize: 15,
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
              decoration: BoxDecoration(
                color: _border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded,
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
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
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
        ],
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
              style: TextStyle(
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
