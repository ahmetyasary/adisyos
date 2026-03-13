import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';

class DailyReportView extends StatelessWidget {
  const DailyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('daily_report'.tr),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        final sales = SalesHistoryService.to.getSalesForDate(today);
        final total = SalesHistoryService.to.getTotalForSales(sales);
        final hourlyTotals = SalesHistoryService.to.getHourlyTotals(today);
        final topItems = SalesHistoryService.to.getTopItems(sales, top: 5);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Text(
                DateFormat('dd MMMM yyyy, EEEE',
                        Get.locale?.languageCode ?? 'tr')
                    .format(today),
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.attach_money,
                      label: 'total_sales'.tr,
                      value: '₺${total.toStringAsFixed(2)}',
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.receipt_long,
                      label: 'sale_count'.tr,
                      value: '${sales.length}',
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.trending_up,
                      label: 'Ort. Sipariş',
                      value: sales.isEmpty
                          ? '₺0.00'
                          : '₺${(total / sales.length).toStringAsFixed(2)}',
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (sales.isEmpty)
                _buildEmptyState(context)
              else ...[
                // Hourly chart
                _buildSectionTitle(context, 'hourly_sales'.tr,
                    Icons.access_time),
                const SizedBox(height: 12),
                _buildHourlyChart(context, hourlyTotals),
                const SizedBox(height: 24),

                // Top items
                if (topItems.isNotEmpty) ...[
                  _buildSectionTitle(
                      context, 'top_items'.tr, Icons.star),
                  const SizedBox(height: 12),
                  _buildTopItemsList(context, topItems),
                ],

                const SizedBox(height: 24),

                // Recent transactions
                _buildSectionTitle(
                    context, 'recent_activity'.tr, Icons.list_alt),
                const SizedBox(height: 12),
                _buildTransactionsList(context, sales),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(
      BuildContext context, Map<int, double> hourlyTotals) {
    if (hourlyTotals.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('-')));
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
            borderRadius: BorderRadius.circular(4),
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '₺${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}:00',
                  style: const TextStyle(fontSize: 10),
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
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildTopItemsList(
      BuildContext context, List<MapEntry<String, double>> topItems) {
    final maxQty = topItems.first.value;
    return Column(
      children: topItems.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;
        final fraction = maxQty > 0 ? item.value / maxQty : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank.',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        Text('${item.value.toInt()} adet',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.accentColor,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
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

  Widget _buildTransactionsList(
      BuildContext context, List<Map<String, dynamic>> sales) {
    final recent = sales.reversed.take(10).toList();
    return Column(
      children: recent.map((sale) {
        final date = DateTime.parse(sale['date'] as String);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
              child: const Icon(Icons.check_circle,
                  color: AppTheme.successColor, size: 20),
            ),
            title: Text(sale['tableName'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${(sale['items'] as List).length} ürün · ${DateFormat('HH:mm').format(date)}'),
            trailing: Text(
              '₺${(sale['total'] as double).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
                fontSize: 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'no_sales_today'.tr,
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
