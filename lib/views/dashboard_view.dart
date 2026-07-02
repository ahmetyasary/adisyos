import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/widgets/day_toggle_card.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);
const _blue = Color(0xFF007AFF);
const _purple = Color(0xFFAF52DE);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFECECEF);
const _chipBg = Color(0xFFF2F2F7);

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Coarse tick: refreshes the "active for / today" boundary and the hero's
    // elapsed label without the cost of a per-second rebuild.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _go(String id) => ShellScope.maybeOf(context)?.selectSection(id);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    // Phone-sized screens get slightly smaller type so values (e.g. large
    // currency amounts) fit without truncating; tablets/desktop keep full size.
    final compact = mq.size.width < 600;

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        final cs = SettingsService.cs;

        final tables = TableService.to.tables;
        final total = tables.length;
        final occupiedCount =
            tables.where((t) => t['isOccupied'] == true).length;
        final occupancyRate = total > 0 ? occupiedCount / total : 0.0;

        final todaySales = SalesHistoryService.to.getSalesForDate(_now);
        final todayTotal = SalesHistoryService.to.getTotalForSales(todaySales);
        final avgOrder =
            todaySales.isNotEmpty ? todayTotal / todaySales.length : 0.0;
        final hourlyTotals = SalesHistoryService.to.getHourlyTotals(_now);
        final pending = KitchenService.to.pendingTickets.length;
        final recent = SalesHistoryService.to.getRecentSales(limit: 4);

        return ListView(
          padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 28),
          children: [
            _Header(
              unread: todaySales.isNotEmpty,
              compact: compact,
              onBell: () => _go('notifications'),
            ),
            const SizedBox(height: 22),
            const DayToggleCard(hero: true),
            const SizedBox(height: 22),

            // KPI grid — flat, professional badges (2×2 on phone, 4-up wide).
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 720 ? 4 : 2;
              const gap = 14.0;
              final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
              final cards = <Widget>[
                _KpiCard(
                  label: 'Bugünkü Satış',
                  value: '$cs${todayTotal.toStringAsFixed(2)}',
                  sub: '${todaySales.length} işlem',
                  icon: CupertinoIcons.arrow_up_right_circle_fill,
                  color: _green,
                  compact: compact,
                ),
                _KpiCard(
                  label: 'Ortalama Sipariş',
                  value: '$cs${avgOrder.toStringAsFixed(2)}',
                  sub: 'işlem başına',
                  icon: CupertinoIcons.cart_fill,
                  color: _orange,
                  compact: compact,
                ),
                _KpiCard(
                  label: 'Doluluk Oranı',
                  value: '${(occupancyRate * 100).toStringAsFixed(0)}%',
                  sub: '$occupiedCount / $total masa',
                  icon: Icons.table_bar_rounded,
                  color: _blue,
                  compact: compact,
                ),
                _KpiCard(
                  label: 'Bekleyen Sipariş',
                  value: '$pending',
                  sub: 'adet',
                  icon: CupertinoIcons.clock_fill,
                  color: _purple,
                  compact: compact,
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in cards) SizedBox(width: itemW, child: card),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Daily sales line chart
            _CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Günlük Satış Grafiği',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 18),
                  _DailyLineChart(hourlyTotals: hourlyTotals, cs: cs),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _orange, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text('Satış Tutarı ($cs)',
                          style:
                              const TextStyle(fontSize: 12, color: _textSec)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Recent transactions
            Row(
              children: [
                const Text(
                  'Son İşlemler',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _go('notifications'),
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (recent.isEmpty)
              const _RecentRow.empty()
            else
              for (int i = 0; i < recent.length; i++) ...[
                _RecentRow(sale: recent[i], cs: cs),
                if (i != recent.length - 1) const SizedBox(height: 10),
              ],
          ],
        );
      }),
    );
  }
}

// ── Header ───────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.compact,
    required this.onBell,
  });
  final bool unread;
  final bool compact;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ana Ekran',
                style: TextStyle(
                  fontSize: compact ? 25 : 30,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Güncel özet bilgileri görüntüleyin.',
                style: TextStyle(fontSize: compact ? 13 : 14, color: _textSec),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _BellButton(unread: unread, onTap: onBell),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(CupertinoIcons.bell, size: 26, color: _textPrimary),
            if (unread)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: _card, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
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
    required this.compact,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: _cardDeco,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: _textSec,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 19 : 24,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.6)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 11 : 12, color: _textSec)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 28),
        ],
      ),
    );
  }
}

// ── Daily line chart ─────────────────────────────────────────

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart({required this.hourlyTotals, required this.cs});
  final Map<int, double> hourlyTotals;
  final String cs;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (int h = 0; h < 24; h++) FlSpot(h.toDouble(), hourlyTotals[h] ?? 0.0),
    ];
    final maxVal =
        hourlyTotals.values.fold<double>(0, (p, e) => math.max(p, e));
    final hasData = maxVal > 0;
    final maxY = hasData ? maxVal * 1.25 : 1.0;
    final interval = maxY / 4;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 24,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _border,
              strokeWidth: 1,
              dashArray: const [4, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (v, _) => Text(
                  hasData ? '$cs${v.toInt()}' : v.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 10, color: _textSec),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final h = v.toInt();
                  final label = switch (h) {
                    0 => '00:00',
                    6 => '06:00',
                    12 => '12:00',
                    18 => '18:00',
                    24 => '23:59',
                    _ => '',
                  };
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label,
                        style: const TextStyle(fontSize: 10, color: _textSec)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: hasData,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.x.toInt()}:00\n$cs${s.y.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: _orange,
              barWidth: hasData ? 3 : 0,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: hasData,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _orange.withValues(alpha: 0.18),
                    _orange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent transaction row ───────────────────────────────────

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.sale, required this.cs}) : empty = false;
  const _RecentRow.empty()
      : sale = null,
        cs = '',
        empty = true;

  final Map<String, dynamic>? sale;
  final String cs;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    if (empty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco,
        child: Row(
          children: const [
            _NeutralChip(icon: CupertinoIcons.doc_text_fill),
            SizedBox(width: 12),
            Expanded(
              child: Text('Henüz işlem bulunmuyor.',
                  style: TextStyle(fontSize: 14, color: _textSec)),
            ),
            Icon(CupertinoIcons.chevron_right, size: 20, color: _textSec),
          ],
        ),
      );
    }

    final s = sale!;
    final tableName = s['tableName'] as String? ?? '';
    final itemCount = (s['items'] as List?)?.length ?? 0;
    final total = (s['total'] as num?)?.toDouble() ?? 0.0;
    final date = DateTime.tryParse(s['date'] as String? ?? '');
    final time = date != null ? DateFormat('HH:mm').format(date) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Row(
        children: [
          const _NeutralChip(icon: CupertinoIcons.doc_text_fill),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tableName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                const SizedBox(height: 2),
                Text('$itemCount ürün${time.isNotEmpty ? ' · $time' : ''}',
                    style: const TextStyle(fontSize: 12, color: _textSec)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$cs${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_right, size: 20, color: _textSec),
        ],
      ),
    );
  }
}

class _NeutralChip extends StatelessWidget {
  const _NeutralChip({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF3A3A3C)),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────

const BoxDecoration _cardDeco = BoxDecoration(
  color: _card,
  borderRadius: BorderRadius.all(Radius.circular(18)),
  border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
  boxShadow: [
    BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
  ],
);

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco,
      child: child,
    );
  }
}
