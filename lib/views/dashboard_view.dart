import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/models/dashboard_layout.dart';
import 'package:orderix/services/digital_menu_order_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/utils/app_haptics.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/day_toggle_card.dart';
import 'package:orderix/widgets/shell_leading.dart';

// ── Design tokens ─────────────────────────────────────────────
Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);
const _blue = Color(0xFF007AFF);
const _purple = Color(0xFFAF52DE);
const _red = Color(0xFFFF3B30);
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.borderSoft;
Color get _chipBg => AppColors.chipBg;

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Timer _clock;
  DateTime _now = DateTime.now();
  bool _editing = false;
  List<DashboardWidgetItem> _draft = [];

  @override
  void initState() {
    super.initState();
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

  bool get _isAdmin => AuthController.to.isAdmin;

  List<DashboardWidgetItem> get _items =>
      _editing ? _draft : SettingsService.to.dashboardLayout.toList();

  void _enterEdit() {
    if (!_isAdmin || _editing) return;
    setState(() {
      _editing = true;
      _draft = SettingsService.to.dashboardLayout
          .map((e) => e.copyWith())
          .toList();
    });
    AppHaptics.medium();
  }

  Future<void> _saveEdit() async {
    await SettingsService.to.setDashboardLayout(_draft);
    if (!mounted) return;
    setState(() => _editing = false);
    AppToast.success('Ana ekran düzeni kaydedildi');
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _draft = [];
    });
  }

  Future<void> _resetDefault() async {
    setState(() => _draft = defaultDashboardLayout());
    AppHaptics.light();
  }

  void _moveTo(int from, int to) {
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      final item = _draft.removeAt(from);
      _draft.insert(to, item);
    });
  }

  void _setSize(String id, DashboardWidgetSize size) {
    final i = _draft.indexWhere((e) => e.id == id);
    if (i < 0 || _draft[i].size == size) return;
    setState(() => _draft[i] = _draft[i].copyWith(size: size));
    AppHaptics.light();
  }

  void _remove(String id) {
    setState(() => _draft.removeWhere((e) => e.id == id));
  }

  void _add(DashboardWidgetType type) {
    if (_draft.any((e) => e.type == type)) {
      AppToast.error('Bu widget zaten ekli');
      return;
    }
    setState(() {
      _draft.add(DashboardWidgetItem(
        id: 'w${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        size: defaultSizeFor(type),
      ));
    });
  }

  Future<void> _showAddSheet() async {
    final used = _draft.map((e) => e.type).toSet();
    final available = DashboardWidgetType.values
        .where((t) => !used.contains(t))
        .toList();
    if (available.isEmpty) {
      AppToast.error('Eklenecek widget kalmadı');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Widget ekle',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            for (final t in available)
              ListTile(
                title: Text(dashboardWidgetTitle(t),
                    style: TextStyle(color: _textPrimary)),
                trailing: Icon(CupertinoIcons.plus_circle_fill,
                    color: _orange),
                onTap: () {
                  Navigator.pop(ctx);
                  _add(t);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final compact = mq.size.width < 600;
    final columns = mq.size.width >= 900
        ? 4
        : mq.size.width >= 600
            ? 3
            : 2;

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        // Reactive deps for live data + layout (content, not only length).
        SettingsService.to.dashboardLayout.toList();
        final cs = SettingsService.cs;
        final tables = TableService.to.tables;
        final total = tables.length;
        final occupied =
            tables.where((t) => t['isOccupied'] == true).toList();
        final occupancyRate = total > 0 ? occupied.length / total : 0.0;
        final todaySales = SalesHistoryService.to.getSalesForDate(_now);
        final todayTotal = SalesHistoryService.to.getTotalForSales(todaySales);
        final avgOrder =
            todaySales.isNotEmpty ? todayTotal / todaySales.length : 0.0;
        final hourlyTotals = SalesHistoryService.to.getHourlyTotals(_now);
        final pendingKitchen = KitchenService.to.pendingTickets.length;
        final recent = SalesHistoryService.to.getRecentSales(limit: 5);
        final topItems =
            SalesHistoryService.to.getTopItems(todaySales, top: 5);
        final digitalPending = Get.isRegistered<DigitalMenuOrderService>()
            ? DigitalMenuOrderService.to.pending.toList()
            : const <Map<String, dynamic>>[];
        final lowStock = Get.isRegistered<InventoryService>()
            ? InventoryService.to.lowStockItems
            : const <MapEntry<String, int>>[];

        final data = _DashData(
          cs: cs,
          todayTotal: todayTotal,
          todayCount: todaySales.length,
          avgOrder: avgOrder,
          occupancyRate: occupancyRate,
          occupiedCount: occupied.length,
          tableTotal: total,
          pendingKitchen: pendingKitchen,
          hourlyTotals: hourlyTotals,
          recent: recent,
          openTables: occupied,
          topItems: topItems,
          digitalPending: digitalPending,
          lowStock: lowStock,
          compact: compact,
          onGo: _go,
        );

        return Column(
          children: [
            Expanded(
              child: _editing
                  ? _buildEditGrid(topPad, data, columns)
                  : GestureDetector(
                      onLongPress: _isAdmin ? _enterEdit : null,
                      child: ListView(
                        padding:
                            EdgeInsets.fromLTRB(20, topPad + 12, 20, 28),
                        children: [
                          _Header(
                            unread: todaySales.isNotEmpty,
                            compact: compact,
                            onBell: () => _go('notifications'),
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(builder: (context, c) {
                            return _PackedGrid(
                              items: _items,
                              columns: columns,
                              maxWidth: c.maxWidth,
                              builder: (item) =>
                                  _widgetBody(item, data, editing: false),
                            );
                          }),
                          if (_isAdmin) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Düzenlemek için uzun basın',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSec.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            if (_editing) _EditToolbar(
              onAdd: _showAddSheet,
              onReset: _resetDefault,
              onCancel: _cancelEdit,
              onSave: _saveEdit,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEditGrid(double topPad, _DashData data, int columns) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 28),
      children: [
        Text(
          'Boyut seçin · uzun basıp sürükleyin',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textSec,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          const gap = 14.0;
          final cell = (c.maxWidth - gap * (columns - 1)) / columns;
          return _PackedGrid(
            items: _draft,
            columns: columns,
            maxWidth: c.maxWidth,
            animate: true,
            builder: (item) {
              final span = dashboardSpanFor(item.size, columns);
              final tileW = span * cell + (span - 1) * gap;
              final tile = _EditTile(
                item: item,
                body: _widgetBody(item, data, editing: true),
                onSize: (s) => _setSize(item.id, s),
                onRemove: () => _remove(item.id),
              );
              return LongPressDraggable<String>(
                data: item.id,
                hapticFeedbackOnStart: false,
                onDragStarted: () => AppHaptics.medium(),
                onDragEnd: (_) => AppHaptics.light(),
                feedback: Material(
                  elevation: 8,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(width: tileW, child: tile),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: tile),
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (d) => d.data != item.id,
                  onAcceptWithDetails: (d) {
                    final from =
                        _draft.indexWhere((e) => e.id == d.data);
                    final to =
                        _draft.indexWhere((e) => e.id == item.id);
                    _moveTo(from, to);
                  },
                  builder: (context, candidate, _) {
                    final hovering = candidate.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: hovering
                            ? [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: tile,
                    );
                  },
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _widgetBody(
    DashboardWidgetItem item,
    _DashData d, {
    required bool editing,
  }) {
    switch (item.type) {
      case DashboardWidgetType.dayToggle:
        return const DayToggleCard(hero: true);
      case DashboardWidgetType.salesToday:
        return _KpiCard(
          label: 'Bugünkü Satış',
          value: '${d.cs}${d.todayTotal.toStringAsFixed(2)}',
          sub: '${d.todayCount} işlem',
          icon: CupertinoIcons.arrow_up_right_circle_fill,
          color: _green,
          compact: d.compact,
        );
      case DashboardWidgetType.avgOrder:
        return _KpiCard(
          label: 'Ortalama Sipariş',
          value: '${d.cs}${d.avgOrder.toStringAsFixed(2)}',
          sub: 'işlem başına',
          icon: CupertinoIcons.cart_fill,
          color: _orange,
          compact: d.compact,
        );
      case DashboardWidgetType.occupancy:
        return _KpiCard(
          label: 'Doluluk Oranı',
          value: '${(d.occupancyRate * 100).toStringAsFixed(0)}%',
          sub: '${d.occupiedCount} / ${d.tableTotal} masa',
          icon: Icons.table_bar_rounded,
          color: _blue,
          compact: d.compact,
        );
      case DashboardWidgetType.kitchenPending:
        return _KpiCard(
          label: 'Bekleyen Sipariş',
          value: '${d.pendingKitchen}',
          sub: 'mutfak',
          icon: CupertinoIcons.clock_fill,
          color: _purple,
          compact: d.compact,
          onTap: editing ? null : () => d.onGo('kitchen'),
        );
      case DashboardWidgetType.salesChart:
        return _CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Günlük Satış Grafiği',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _DailyLineChart(hourlyTotals: d.hourlyTotals, cs: d.cs),
            ],
          ),
        );
      case DashboardWidgetType.recentSales:
        return _ListCard(
          title: 'Son İşlemler',
          actionLabel: editing ? null : 'Tümünü Gör',
          onAction: editing ? null : () => d.onGo('notifications'),
          child: d.recent.isEmpty
              ? const _RecentRow.empty()
              : Column(
                  children: [
                    for (int i = 0; i < d.recent.length; i++) ...[
                      _RecentRow(sale: d.recent[i], cs: d.cs),
                      if (i != d.recent.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
        );
      case DashboardWidgetType.openTables:
        return _ListCard(
          title: 'Açık Masalar',
          actionLabel: editing ? null : 'Masalar',
          onAction: editing ? null : () => d.onGo('tables'),
          child: d.openTables.isEmpty
              ? _EmptyHint('Açık masa yok')
              : Column(
                  children: [
                    for (final t in d.openTables.take(6))
                      _SimpleRow(
                        title: '${t['name'] ?? 'Masa'}',
                        trailing:
                            '${d.cs}${((t['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                      ),
                  ],
                ),
        );
      case DashboardWidgetType.topItems:
        return _ListCard(
          title: 'En Çok Satanlar',
          child: d.topItems.isEmpty
              ? _EmptyHint('Bugün satış yok')
              : Column(
                  children: [
                    for (final e in d.topItems)
                      _SimpleRow(
                        title: e.key,
                        trailing: '${e.value.toStringAsFixed(0)} adet',
                      ),
                  ],
                ),
        );
      case DashboardWidgetType.digitalPending:
        return _ListCard(
          title: 'Dijital Menü Siparişleri',
          actionLabel: editing ? null : 'Bekleyenler',
          onAction: editing ? null : () => d.onGo('pending_orders'),
          child: d.digitalPending.isEmpty
              ? _EmptyHint('Bekleyen QR sipariş yok')
              : Column(
                  children: [
                    for (final o in d.digitalPending.take(5))
                      _SimpleRow(
                        title:
                            '${o['table_name'] ?? o['tableName'] ?? o['table'] ?? 'Sipariş'}',
                        trailing:
                            '${(o['items'] as List?)?.length ?? 0} kalem',
                      ),
                  ],
                ),
        );
      case DashboardWidgetType.stockAlerts:
        return _ListCard(
          title: 'Stok Uyarıları',
          actionLabel: editing ? null : 'Stoklar',
          onAction: editing ? null : () => d.onGo('inventory'),
          child: d.lowStock.isEmpty
              ? _EmptyHint('Düşük stok yok')
              : Column(
                  children: [
                    for (final e in d.lowStock.take(6))
                      _SimpleRow(
                        title: e.key,
                        trailing: '${e.value}',
                        trailingColor: _red,
                      ),
                  ],
                ),
        );
    }
  }
}

class _DashData {
  const _DashData({
    required this.cs,
    required this.todayTotal,
    required this.todayCount,
    required this.avgOrder,
    required this.occupancyRate,
    required this.occupiedCount,
    required this.tableTotal,
    required this.pendingKitchen,
    required this.hourlyTotals,
    required this.recent,
    required this.openTables,
    required this.topItems,
    required this.digitalPending,
    required this.lowStock,
    required this.compact,
    required this.onGo,
  });

  final String cs;
  final double todayTotal;
  final int todayCount;
  final double avgOrder;
  final double occupancyRate;
  final int occupiedCount;
  final int tableTotal;
  final int pendingKitchen;
  final Map<int, double> hourlyTotals;
  final List<Map<String, dynamic>> recent;
  final List<Map<String, dynamic>> openTables;
  final List<MapEntry<String, double>> topItems;
  final List<Map<String, dynamic>> digitalPending;
  final List<MapEntry<String, int>> lowStock;
  final bool compact;
  final void Function(String id) onGo;
}

// ── Packed grid (view mode) ───────────────────────────────────

class _PackedGrid extends StatelessWidget {
  const _PackedGrid({
    required this.items,
    required this.columns,
    required this.maxWidth,
    required this.builder,
    this.animate = false,
  });

  final List<DashboardWidgetItem> items;
  final int columns;
  final double maxWidth;
  final Widget Function(DashboardWidgetItem) builder;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final cell = (maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in items)
          _gridChild(
            item: item,
            width: () {
              final span = dashboardSpanFor(item.size, columns);
              return span * cell + (span - 1) * gap;
            }(),
          ),
      ],
    );
  }

  Widget _gridChild({
    required DashboardWidgetItem item,
    required double width,
  }) {
    final child = builder(item);
    if (!animate) return SizedBox(width: width, child: child);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: child,
    );
  }
}

// ── Edit chrome ───────────────────────────────────────────────

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.item,
    required this.body,
    required this.onSize,
    required this.onRemove,
  });

  final DashboardWidgetItem item;
  final Widget body;
  final ValueChanged<DashboardWidgetSize> onSize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isSmall = item.size == DashboardWidgetSize.small;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withValues(alpha: 0.45), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: _chipBg,
            padding: EdgeInsets.fromLTRB(8, 6, 6, isSmall ? 8 : 6),
            child: isSmall ? _compactChrome() : _wideChrome(),
          ),
          body,
        ],
      ),
    );
  }

  Widget _wideChrome() {
    return Row(
      children: [
        Icon(CupertinoIcons.line_horizontal_3, color: _textSec, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            dashboardWidgetTitle(item.type),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
        _sizeGroup(),
        _deleteBtn(),
      ],
    );
  }

  /// S boyutta tek satıra sığmaz: üstte başlık, altta boyutlar.
  Widget _compactChrome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.line_horizontal_3, color: _textSec, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                dashboardWidgetTitle(item.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            _deleteBtn(),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _sizeGroup(),
        ),
      ],
    );
  }

  Widget _sizeGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in DashboardWidgetSize.values)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: _SizeChip(
              label: switch (s) {
                DashboardWidgetSize.small => 'S',
                DashboardWidgetSize.medium => 'M',
                DashboardWidgetSize.large => 'L',
              },
              selected: item.size == s,
              onTap: () => onSize(s),
            ),
          ),
      ],
    );
  }

  Widget _deleteBtn() {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(CupertinoIcons.trash, size: 16, color: _red),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _orange : _card,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? _orange : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _textSec,
          ),
        ),
      ),
    );
  }
}

class _EditToolbar extends StatelessWidget {
  const _EditToolbar({
    required this.onAdd,
    required this.onReset,
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onAdd;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(onPressed: onReset, child: const Text('Sıfırla')),
          TextButton(onPressed: onAdd, child: const Text('Ekle')),
          const Spacer(),
          TextButton(onPressed: onCancel, child: const Text('Vazgeç')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: const Text('Kaydet'),
          ),
        ],
      ),
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
        ShellLeading(embedded: true),
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
              Obx(() {
                final name = SettingsService.to.companyName.value.trim();
                return Text(
                  name.isEmpty ? 'Güncel özet bilgileri' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: compact ? 13 : 14, color: _textSec),
                );
              }),
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
            Icon(CupertinoIcons.bell, size: 26, color: _textPrimary),
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

// ── Shared cards ─────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.compact,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
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
                        fontSize: compact ? 19 : 22,
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
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13, color: _textSec));
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.title,
    required this.trailing,
    this.trailingColor,
  });

  final String title;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: trailingColor ?? _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

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
      height: 180,
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
                  style: TextStyle(fontSize: 10, color: _textSec),
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
                        style: TextStyle(fontSize: 10, color: _textSec)),
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
      return Text('Henüz işlem bulunmuyor.',
          style: TextStyle(fontSize: 14, color: _textSec));
    }

    final s = sale!;
    final tableName = s['tableName'] as String? ?? '';
    final itemCount = (s['items'] as List?)?.length ?? 0;
    final total = (s['total'] as num?)?.toDouble() ?? 0.0;
    final date = DateTime.tryParse(s['date'] as String? ?? '');
    final time = date != null ? DateFormat('HH:mm').format(date) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tableName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                Text('$itemCount ürün${time.isNotEmpty ? ' · $time' : ''}',
                    style: TextStyle(fontSize: 12, color: _textSec)),
              ],
            ),
          ),
          Text('$cs${total.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ],
      ),
    );
  }
}

BoxDecoration get _cardDeco => BoxDecoration(
      color: _card,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
      boxShadow: AppColors.cardShadow,
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
