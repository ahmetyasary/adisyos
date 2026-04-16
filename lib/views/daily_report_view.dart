import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/services/settings_service.dart';

/// Returns "Section · tableName" when a live table with that name has a section.
String _resolveTableLabel(String rawName) {
  final tables = TableService.to.tables;
  final match = tables.firstWhereOrNull(
      (t) => (t['name'] as String) == rawName);
  if (match == null) return rawName;
  final sectionId = match['sectionId'] as String?;
  final sectionName = SectionService.to.nameById(sectionId);
  if (sectionName != null && sectionName.isNotEmpty) {
    return '$sectionName · $rawName';
  }
  return rawName;
}

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
        top: false,
        child: Column(
          children: [
            _Header(title: 'daily_report'.tr),
            Expanded(
              child: Obx(() {
                final cs = SettingsService.cs;
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
                              label: 'Ort. Sipariş',
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
                            title: 'hourly_sales'.tr,
                            icon: Icons.access_time_rounded),
                        const SizedBox(height: 12),
                        _ChartCard(
                            child: _buildHourlyLineChart(hourlyTotals, cs)),
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
                                total, cs)),
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

                        // Son Aktivite — table-grouped
                        _SectionTitle(
                            title: 'recent_activity'.tr,
                            icon: Icons.list_alt_rounded),
                        const SizedBox(height: 12),
                        _buildTableGroupedActivity(sales, cs),
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

  // ── Hourly line chart (upgraded from bar chart) ───────────────
  Widget _buildHourlyLineChart(Map<int, double> hourlyTotals, String cs) {
    if (hourlyTotals.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text('-')));
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
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown(
      Map<String, double> totals, double grandTotal, String cs) {
    final methods = [
      {'key': 'cash',     'label': 'pay_cash',     'icon': Icons.payments_rounded,        'color': const Color(0xFF52C97F)},
      {'key': 'card',     'label': 'pay_card',     'icon': Icons.credit_card_rounded,     'color': const Color(0xFF5DADE2)},
      {'key': 'transfer', 'label': 'pay_transfer', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFFAB84F5)},
    ];
    return Column(
      children: methods.map((m) {
        final amount   = totals[m['key'] as String] ?? 0.0;
        final fraction = grandTotal > 0 ? amount / grandTotal : 0.0;
        final color    = m['color'] as Color;
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
        final rank     = entry.key + 1;
        final item     = entry.value;
        final fraction = maxQty > 0 ? item.value / maxQty : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
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

  // ── Son Aktivite: table-grouped ───────────────────────────────
  Widget _buildTableGroupedActivity(List<Map<String, dynamic>> sales, String cs) {
    // Group by tableName, preserve order (newest first already)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final sale in sales) {
      final name = sale['tableName'] as String;
      grouped.putIfAbsent(name, () => []).add(sale);
    }

    // Sort tables by their most recent sale (already newest-first in each group)
    final tableNames = grouped.keys.toList()
      ..sort((a, b) {
        final aDate = DateTime.parse(grouped[a]!.first['date'] as String);
        final bDate = DateTime.parse(grouped[b]!.first['date'] as String);
        return bDate.compareTo(aDate);
      });

    return Column(
      children: tableNames.map((tableName) {
        final tableSales = grouped[tableName]!;
        final tableTotal = tableSales.fold(
            0.0, (sum, s) => sum + (s['total'] as double));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 20,
                  offset: Offset(0, 4)),
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 5,
                  offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentColor.withValues(alpha: 0.10),
                      AppTheme.accentColor.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.table_restaurant_rounded,
                          color: AppTheme.accentColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _resolveTableLabel(tableName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$cs${tableTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Individual sales for this table
              ...tableSales.asMap().entries.map((entry) {
                final idx  = entry.key;
                final sale = entry.value;
                final date =
                    DateTime.parse(sale['date'] as String);
                final items = (sale['items'] as List)
                    .cast<Map<String, dynamic>>();
                final method =
                    (sale['paymentMethod'] as String?) ?? 'cash';
                final isLast =
                    idx == tableSales.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Time + payment method row
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: _textSec),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSec,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 10),
                              _PayMethodBadge(method: method),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Item list
                          ...items.map((item) {
                            final qty =
                                (item['quantity'] as num).toInt();
                            final price =
                                (item['price'] as num).toDouble();
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      color: _bg,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['name'] as String,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _textPrimary),
                                    ),
                                  ),
                                  Text(
                                    '$cs${(qty * price).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Sale total row
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              Text(
                                '${items.length} ürün · ',
                                style: const TextStyle(
                                    fontSize: 12, color: _textSec),
                              ),
                              Text(
                                '$cs${(sale['total'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16,
                          color: _border),
                  ],
                );
              }),
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
              'no_sales_today'.tr,
              style: const TextStyle(color: _textSec, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment method badge ──────────────────────────────────────
class _PayMethodBadge extends StatelessWidget {
  const _PayMethodBadge({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (method) {
      'card'     => ('Kart',   Icons.credit_card_rounded,     const Color(0xFF5DADE2)),
      'transfer' => ('Havale', Icons.account_balance_rounded, const Color(0xFFAB84F5)),
      _          => ('Nakit',  Icons.payments_rounded,        const Color(0xFF52C97F)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
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
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, 0.28)!, accent],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
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
