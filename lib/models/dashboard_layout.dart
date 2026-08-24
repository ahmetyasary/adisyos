import 'dart:convert';

/// Dashboard widget kinds the admin can place on Ana Ekran.
enum DashboardWidgetType {
  dayToggle,
  salesToday,
  avgOrder,
  occupancy,
  kitchenPending,
  salesChart,
  recentSales,
  openTables,
  topItems,
  digitalPending,
  stockAlerts,
}

enum DashboardWidgetSize {
  /// 1 column
  small,

  /// 2 columns (or full width on 2-col phone when alone)
  medium,

  /// Full row
  large,
}

class DashboardWidgetItem {
  const DashboardWidgetItem({
    required this.id,
    required this.type,
    required this.size,
  });

  final String id;
  final DashboardWidgetType type;
  final DashboardWidgetSize size;

  DashboardWidgetItem copyWith({
    String? id,
    DashboardWidgetType? type,
    DashboardWidgetSize? size,
  }) =>
      DashboardWidgetItem(
        id: id ?? this.id,
        type: type ?? this.type,
        size: size ?? this.size,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'size': size.name,
      };

  static DashboardWidgetItem? fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final sizeName = json['size'] as String?;
    final id = json['id'] as String?;
    if (typeName == null || sizeName == null || id == null) return null;
    final type = DashboardWidgetType.values
        .where((e) => e.name == typeName)
        .firstOrNull;
    final size = DashboardWidgetSize.values
        .where((e) => e.name == sizeName)
        .firstOrNull;
    if (type == null || size == null) return null;
    return DashboardWidgetItem(id: id, type: type, size: size);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

/// Default layout (matches classic Ana Ekran + day card first).
List<DashboardWidgetItem> defaultDashboardLayout() {
  var n = 0;
  String nid() => 'w${n++}';
  return [
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.dayToggle,
      size: DashboardWidgetSize.large,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.salesToday,
      size: DashboardWidgetSize.small,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.avgOrder,
      size: DashboardWidgetSize.small,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.occupancy,
      size: DashboardWidgetSize.small,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.kitchenPending,
      size: DashboardWidgetSize.small,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.salesChart,
      size: DashboardWidgetSize.large,
    ),
    DashboardWidgetItem(
      id: nid(),
      type: DashboardWidgetType.recentSales,
      size: DashboardWidgetSize.large,
    ),
  ];
}

String encodeDashboardLayout(List<DashboardWidgetItem> items) =>
    jsonEncode(items.map((e) => e.toJson()).toList());

List<DashboardWidgetItem> parseDashboardLayout(String? raw) {
  if (raw == null || raw.trim().isEmpty) return defaultDashboardLayout();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return defaultDashboardLayout();
    final out = <DashboardWidgetItem>[];
    for (final e in decoded) {
      if (e is Map<String, dynamic>) {
        final item = DashboardWidgetItem.fromJson(e);
        if (item != null) out.add(item);
      } else if (e is Map) {
        final item =
            DashboardWidgetItem.fromJson(Map<String, dynamic>.from(e));
        if (item != null) out.add(item);
      }
    }
    return out.isEmpty ? defaultDashboardLayout() : out;
  } catch (_) {
    return defaultDashboardLayout();
  }
}

int dashboardSpanFor(DashboardWidgetSize size, int columns) {
  switch (size) {
    case DashboardWidgetSize.small:
      return 1;
    case DashboardWidgetSize.medium:
      return columns >= 2 ? 2 : 1;
    case DashboardWidgetSize.large:
      return columns;
  }
}

String dashboardWidgetTitle(DashboardWidgetType type) {
  switch (type) {
    case DashboardWidgetType.dayToggle:
      return 'Gün durumu';
    case DashboardWidgetType.salesToday:
      return 'Bugünkü satış';
    case DashboardWidgetType.avgOrder:
      return 'Ortalama sipariş';
    case DashboardWidgetType.occupancy:
      return 'Doluluk';
    case DashboardWidgetType.kitchenPending:
      return 'Bekleyen mutfak';
    case DashboardWidgetType.salesChart:
      return 'Günlük satış grafiği';
    case DashboardWidgetType.recentSales:
      return 'Son işlemler';
    case DashboardWidgetType.openTables:
      return 'Açık masalar';
    case DashboardWidgetType.topItems:
      return 'En çok satanlar';
    case DashboardWidgetType.digitalPending:
      return 'Dijital menü siparişleri';
    case DashboardWidgetType.stockAlerts:
      return 'Stok uyarıları';
  }
}

DashboardWidgetSize defaultSizeFor(DashboardWidgetType type) {
  switch (type) {
    case DashboardWidgetType.dayToggle:
    case DashboardWidgetType.salesChart:
    case DashboardWidgetType.recentSales:
    case DashboardWidgetType.openTables:
    case DashboardWidgetType.topItems:
    case DashboardWidgetType.digitalPending:
    case DashboardWidgetType.stockAlerts:
      return DashboardWidgetSize.large;
    case DashboardWidgetType.salesToday:
    case DashboardWidgetType.avgOrder:
    case DashboardWidgetType.occupancy:
    case DashboardWidgetType.kitchenPending:
      return DashboardWidgetSize.small;
  }
}
