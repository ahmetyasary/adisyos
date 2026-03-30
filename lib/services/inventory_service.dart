import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryService extends GetxService {
  static InventoryService get to => Get.find();

  /// itemName → stock count.  -1 = unlimited / not tracked.
  final RxMap<String, int> stock = <String, int>{}.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  static const int lowStockThreshold = 5;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _load();
    });
    _load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('inventory_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  void _err(String tag, Object e) {
    if (kDebugMode) print('[InventoryService] $tag error: $e');
  }

  // ── Load ────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await _db.from('inventory').select('item_name, stock');
      stock.assignAll({
        for (final r in rows) r['item_name'] as String: r['stock'] as int,
      });
    } catch (e) {
      _err('load', e);
    }
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  // ── Queries ──────────────────────────────────────────────────

  int getStock(String itemName) => stock[itemName] ?? -1;

  bool isTracked(String itemName) => stock.containsKey(itemName);

  bool isLowStock(String itemName) {
    final s = getStock(itemName);
    return s != -1 && s > 0 && s <= lowStockThreshold;
  }

  bool isOutOfStock(String itemName) {
    final s = getStock(itemName);
    return s != -1 && s <= 0;
  }

  List<MapEntry<String, int>> get lowStockItems {
    return stock.entries
        .where((e) => e.value >= 0 && e.value <= lowStockThreshold)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  // ── Mutations ────────────────────────────────────────────────

  void setStock(String itemName, int count) {
    stock[itemName] = count;
    stock.refresh();
    _db.from('inventory').upsert(
      {'item_name': itemName, 'stock': count, 'updated_at': DateTime.now().toIso8601String()},
      onConflict: 'item_name',
    ).catchError((e) => _err('setStock', e));
  }

  void removeTracking(String itemName) {
    stock.remove(itemName);
    stock.refresh();
    _db.from('inventory')
        .delete()
        .eq('item_name', itemName)
        .catchError((e) => _err('removeTracking', e));
  }

  /// Called when order items are cancelled/removed — restores tracked stock.
  void incrementForCancellation(List<Map<String, dynamic>> items) {
    final updates = <String, int>{};
    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      final current = getStock(name);
      if (current != -1) {
        final next = current + qty;
        stock[name] = next;
        updates[name] = next;
      }
    }
    if (updates.isEmpty) return;
    stock.refresh();
    _db.from('inventory').upsert(
      updates.entries
          .map((e) => {
                'item_name': e.key,
                'stock': e.value,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList(),
      onConflict: 'item_name',
    ).catchError((e) => _err('incrementForCancellation', e));
  }

  /// Called when items are added to an order — decrements tracked items instantly.
  void decrementForSale(List<Map<String, dynamic>> items) {
    final updates = <String, int>{};

    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      final current = getStock(name);
      if (current != -1) {
        final next = (current - qty).clamp(0, current);
        stock[name] = next;
        updates[name] = next;
      }
    }

    if (updates.isEmpty) return;
    stock.refresh();

    _db.from('inventory').upsert(
      updates.entries
          .map((e) => {
                'item_name': e.key,
                'stock': e.value,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList(),
      onConflict: 'item_name',
    ).catchError((e) => _err('decrementForSale', e));
  }
}
