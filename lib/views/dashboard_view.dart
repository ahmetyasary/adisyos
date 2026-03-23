import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _orangeLight = Color(0xFFFFF4E0);
const _green       = Color(0xFF34C759);
const _blue        = Color(0xFF007AFF);
const _purple      = Color(0xFFAF52DE);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(now: _now),
            Expanded(
              child: Obx(() {
                final tables = TableService.to.tables;
                final occupied =
                    tables.where((t) => t['isOccupied'] == true).toList();
                final total = tables.length;
                final occupiedCount = occupied.length;
                final freeCount = total - occupiedCount;
                final occupancyRate =
                    total > 0 ? occupiedCount / total : 0.0;

                final todaySales =
                    SalesHistoryService.to.getSalesForDate(_now);
                final todayTotal =
                    SalesHistoryService.to.getTotalForSales(todaySales);
                final hourlyTotals =
                    SalesHistoryService.to.getHourlyTotals(_now);
                final payTotals = SalesHistoryService.to
                    .getPaymentMethodTotals(todaySales);
                final avgOrder = todaySales.isNotEmpty
                    ? todayTotal / todaySales.length
                    : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI row
                      LayoutBuilder(builder: (context, cst) {
                        final isNarrow = cst.maxWidth < 500;
                        final kpiCards = [
                          _KpiCard(
                            label: 'Bugünkü Satış',
                            value: '₺${todayTotal.toStringAsFixed(0)}',
                            sub: '${todaySales.length} işlem',
                            icon: Icons.attach_money_rounded,
                            color: _green,
                          ),
                          _KpiCard(
                            label: 'Ort. Sipariş',
                            value: '₺${avgOrder.toStringAsFixed(0)}',
                            sub: 'işlem başına',
                            icon: Icons.trending_up_rounded,
                            color: _orange,
                          ),
                          _KpiCard(
                            label: 'Doluluk',
                            value:
                                '${(occupancyRate * 100).toStringAsFixed(0)}%',
                            sub: '$occupiedCount / $total masa',
                            icon: Icons.table_bar_rounded,
                            color: _blue,
                          ),
                        ];
                        if (isNarrow) {
                          return Column(
                            children: kpiCards
                                .map((c) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: c))
                                .toList(),
                          );
                        }
                        return Row(
                          children: kpiCards
                              .expand((c) => [
                                    Expanded(child: c),
                                    const SizedBox(width: 12)
                                  ])
                              .toList()
                            ..removeLast(),
                        );
                      }),
                      const SizedBox(height: 24),

                      // Occupancy donut + active tables
                      LayoutBuilder(builder: (context, cst) {
                        final isNarrow = cst.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _OccupancyDonut(
                                occupiedCount: occupiedCount,
                                freeCount: freeCount,
                                total: total,
                              ),
                              const SizedBox(height: 16),
                              _ActiveTablesList(occupiedTables: occupied),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _OccupancyDonut(
                                occupiedCount: occupiedCount,
                                freeCount: freeCount,
                                total: total,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _ActiveTablesList(
                                  occupiedTables: occupied),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 24),

                      // Hourly sales chart
                      _SectionTitle(
                          title: 'Saatlik Satışlar',
                          icon: Icons.access_time_rounded),
                      const SizedBox(height: 12),
                      _CardBox(child: _HourlyChart(hourlyTotals: hourlyTotals)),
                      const SizedBox(height: 24),

                      // Payment method breakdown
                      _SectionTitle(
                          title: 'Ödeme Yöntemleri',
                          icon: Icons.pie_chart_rounded),
                      const SizedBox(height: 12),
                      _PaymentBreakdownRow(
                          payTotals: payTotals, total: todayTotal),
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
}

// ── Header ───────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.now});
  final DateTime now;

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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _textPrimary),
            onPressed: () => Get.back(),
          ),
          const Text(
            'Canlı Dashboard',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.3),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm:ss').format(now),
                  style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6)),
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.25)!, color],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _textSec, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -0.4)),
              Text(sub,   style: const TextStyle(fontSize: 11, color: _textSec)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Occupancy Donut ──────────────────────────────────────────

class _OccupancyDonut extends StatelessWidget {
  const _OccupancyDonut({
    required this.occupiedCount,
    required this.freeCount,
    required this.total,
  });
  final int occupiedCount;
  final int freeCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Masa Doluluk Oranı',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: total == 0
                ? const Center(
                    child: Text('Masa yok',
                        style: TextStyle(color: _textSec)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          value: occupiedCount.toDouble(),
                          color: _orange,
                          title: '$occupiedCount',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                          radius: 36,
                        ),
                        PieChartSectionData(
                          value: freeCount.toDouble(),
                          color: _border,
                          title: '$freeCount',
                          titleStyle: const TextStyle(
                              color: _textSec,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                          radius: 36,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: _orange, label: 'Dolu ($occupiedCount)'),
              const SizedBox(width: 16),
              _Legend(color: _border, label: 'Boş ($freeCount)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: _textSec)),
      ],
    );
  }
}

// ── Active Tables List ────────────────────────────────────────

class _ActiveTablesList extends StatelessWidget {
  const _ActiveTablesList({required this.occupiedTables});
  final List<Map<String, dynamic>> occupiedTables;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktif Masalar (${occupiedTables.length})',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary),
          ),
          const SizedBox(height: 12),
          if (occupiedTables.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Aktif masa yok',
                    style: TextStyle(color: _textSec)),
              ),
            )
          else
            ...occupiedTables.take(6).map((t) {
              final orders = t['orders'] as List;
              final total = t['total'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _orangeLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t['name'] as String,
                        style: const TextStyle(
                            color: _orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${orders.length} ürün',
                        style: const TextStyle(
                            fontSize: 12, color: _textSec)),
                    const Spacer(),
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textPrimary),
                    ),
                  ],
                ),
              );
            }),
          if (occupiedTables.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${occupiedTables.length - 6} daha',
                style:
                    const TextStyle(fontSize: 12, color: _textSec),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hourly Chart ─────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.hourlyTotals});
  final Map<int, double> hourlyTotals;

  @override
  Widget build(BuildContext context) {
    if (hourlyTotals.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text('Henüz satış yok',
              style: TextStyle(color: _textSec)),
        ),
      );
    }
    final maxY =
        hourlyTotals.values.reduce((a, b) => a > b ? a : b);
    final groups = hourlyTotals.entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: AppTheme.accentColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${group.x}:00\n₺${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  '₺${v.toInt()}',
                  style:
                      const TextStyle(fontSize: 9, color: _textSec),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}:00',
                  style:
                      const TextStyle(fontSize: 9, color: _textSec),
                ),
              ),
            ),
            rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _border, strokeWidth: 1),
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}

// ── Payment Breakdown Row ─────────────────────────────────────

class _PaymentBreakdownRow extends StatelessWidget {
  const _PaymentBreakdownRow(
      {required this.payTotals, required this.total});
  final Map<String, double> payTotals;
  final double total;

  @override
  Widget build(BuildContext context) {
    final methods = [
      {'key': 'cash', 'label': 'Nakit', 'icon': Icons.payments_rounded, 'color': _green},
      {'key': 'card', 'label': 'Kart', 'icon': Icons.credit_card_rounded, 'color': _blue},
      {'key': 'transfer', 'label': 'Havale', 'icon': Icons.account_balance_rounded, 'color': _purple},
    ];

    return LayoutBuilder(builder: (context, cst) {
      final isNarrow = cst.maxWidth < 500;
      final tiles = methods.map((m) {
        final amount = payTotals[m['key'] as String] ?? 0.0;
        final pct = total > 0 ? (amount / total * 100) : 0.0;
        final color = m['color'] as Color;
        return _PayTile(
          label: m['label'] as String,
          icon: m['icon'] as IconData,
          amount: amount,
          pct: pct,
          color: color,
        );
      }).toList();

      if (isNarrow) {
        return Column(
          children: tiles
              .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12), child: t))
              .toList(),
        );
      }
      return Row(
        children: tiles
            .expand((t) => [Expanded(child: t), const SizedBox(width: 12)])
            .toList()
          ..removeLast(),
      );
    });
  }
}

class _PayTile extends StatelessWidget {
  const _PayTile({
    required this.label,
    required this.icon,
    required this.amount,
    required this.pct,
    required this.color,
  });
  final String label;
  final IconData icon;
  final double amount;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₺${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: _border,
            color: color,
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style:
                const TextStyle(fontSize: 11, color: _textSec),
          ),
        ],
      ),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────

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
              letterSpacing: -0.2),
        ),
      ],
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}
