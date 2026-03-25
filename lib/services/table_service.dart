import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/kitchen_service.dart';
import 'package:adisyos/services/inventory_service.dart';
import 'package:adisyos/services/staff_service.dart';

class TableService extends GetxService {
  static TableService get to => Get.find();

  final RxList<Map<String, dynamic>> tables = <Map<String, dynamic>>[].obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  @override
  void onClose() {
    if (_channel != null) _db.removeChannel(_channel!);
    super.onClose();
  }

  Future<void> _init() async {
    await _load();
    _subscribeRealtime();
  }

  // ── Load ────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('tables')
          .select('*, orders(*)')
          .order('id');

      tables.assignAll(rows.map(_rowToTable).toList());
    } catch (e) {
      if (kDebugMode) print('[TableService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToTable(Map<String, dynamic> row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
        'isOccupied': row['is_occupied'] as bool,
        'total': (row['total'] as num).toDouble(),
        'discount': (row['discount'] as num).toDouble(),
        'staffEmail': (row['staff_email'] as String?) ?? '',
        'orders': (row['orders'] as List)
            .map((o) => <String, dynamic>{
                  'id': o['id'] as int,
                  'name': o['name'] as String,
                  'quantity': o['quantity'] as int,
                  'price': (o['price'] as num).toDouble(),
                })
            .toList(),
      };

  // ── Realtime ─────────────────────────────────────────────────

  void _subscribeRealtime() {
    _channel = _db
        .channel('tables_and_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tables',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Helpers ──────────────────────────────────────────────────

  int _id(int tableIndex) => tables[tableIndex]['id'] as int;

  Future<void> _syncTableHeader(int tableIndex) async {
    final t = tables[tableIndex];
    await _db.from('tables').update({
      'is_occupied': t['isOccupied'] as bool,
      'total': t['total'] as double,
      'discount': t['discount'] as double,
      'staff_email': t['staffEmail'] as String,
    }).eq('id', _id(tableIndex));
  }

  void _assignStaff(int tableIndex) {
    if ((tables[tableIndex]['staffEmail'] as String).isNotEmpty) return;
    try {
      final name = StaffService.to.currentStaffIdentifier;
      if (name.isNotEmpty) tables[tableIndex]['staffEmail'] = name;
    } catch (_) {}
  }

  // ── Table CRUD ───────────────────────────────────────────────

  Future<void> addTable(String name, {String? sectionId}) async {
    try {
      final insertPayload = <String, dynamic>{
        'name': name,
        'is_occupied': false,
        'total': 0.0,
        'discount': 0.0,
        'staff_email': '',
        if (sectionId != null) 'section_id': sectionId,
      };
      final row = await _db
          .from('tables')
          .insert(insertPayload)
          .select()
          .single();

      tables.add({
        'id': row['id'] as int,
        'name': name,
        'isOccupied': false,
        'total': 0.0,
        'discount': 0.0,
        'staffEmail': '',
        'sectionId': sectionId,
        'orders': <Map<String, dynamic>>[],
      });
    } catch (e) {
      if (kDebugMode) print('[TableService] addTable error: $e');
    }
  }

  Future<void> removeTable(int index) async {
    final tableId = _id(index);
    await KitchenService.to.removeTicketsForTable(tableId);
    tables.removeAt(index);
    try {
      // orders cascade-delete via FK
      await _db.from('tables').delete().eq('id', tableId);
    } catch (e) {
      if (kDebugMode) print('[TableService] removeTable error: $e');
    }
  }

  Future<void> updateTableName(int index, String newName) async {
    tables[index]['name'] = newName;
    tables.refresh();
    try {
      await _db.from('tables').update({'name': newName}).eq('id', _id(index));
    } catch (e) {
      if (kDebugMode) print('[TableService] updateTableName error: $e');
    }
  }

  Future<void> toggleTableStatus(int index) async {
    tables[index]['isOccupied'] = !(tables[index]['isOccupied'] as bool);
    tables.refresh();
    try {
      await _db.from('tables').update({
        'is_occupied': tables[index]['isOccupied'] as bool,
      }).eq('id', _id(index));
    } catch (e) {
      if (kDebugMode) print('[TableService] toggleTableStatus error: $e');
    }
  }

  void _setOccupied(int tableIndex) {
    final orders = tables[tableIndex]['orders'] as List;
    tables[tableIndex]['isOccupied'] = orders.isNotEmpty;
    tables.refresh();
  }

  // ── Order mutations ──────────────────────────────────────────

  Future<void> addOrder(int tableIndex, String name, double price) async {
    final tableId = _id(tableIndex);
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    final existingIdx = orders.indexWhere((o) => o['name'] == name);

    if (existingIdx != -1) {
      final newQty = (orders[existingIdx]['quantity'] as int) + 1;
      final orderId = orders[existingIdx]['id'] as int;
      orders[existingIdx]['quantity'] = newQty;
      tables[tableIndex]['total'] =
          (tables[tableIndex]['total'] as double) + price;

      _assignStaff(tableIndex);
      _setOccupied(tableIndex);

      KitchenService.to.addOrUpdateTicket(
        tableId: tableId,
        tableName: tables[tableIndex]['name'] as String,
        itemName: name,
        quantity: newQty,
      );

      try {
        await _db.from('orders').update({'quantity': newQty}).eq('id', orderId);
        await _syncTableHeader(tableIndex);
      } catch (e) {
        if (kDebugMode) print('[TableService] addOrder (update) error: $e');
      }
    } else {
      // Optimistic: placeholder id = -1 until insert resolves
      orders.add(<String, dynamic>{'id': -1, 'name': name, 'quantity': 1, 'price': price});
      tables[tableIndex]['total'] =
          (tables[tableIndex]['total'] as double) + price;

      _assignStaff(tableIndex);
      _setOccupied(tableIndex);

      KitchenService.to.addOrUpdateTicket(
        tableId: tableId,
        tableName: tables[tableIndex]['name'] as String,
        itemName: name,
        quantity: 1,
      );

      try {
        final row = await _db
            .from('orders')
            .insert({'table_id': tableId, 'name': name, 'quantity': 1, 'price': price})
            .select()
            .single();

        // Patch the placeholder with the real id
        final idx = orders.indexWhere((o) => o['name'] == name && o['id'] == -1);
        if (idx != -1) orders[idx]['id'] = row['id'] as int;

        await _syncTableHeader(tableIndex);
      } catch (e) {
        if (kDebugMode) print('[TableService] addOrder (insert) error: $e');
      }
    }
  }

  Future<void> removeOrder(int tableIndex, int orderIndex) async {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    if (orderIndex >= orders.length) return;

    final order = orders[orderIndex];
    final orderId = order['id'] as int;
    final price = order['price'] as double;
    final qty = order['quantity'] as int;
    final name = order['name'] as String;

    tables[tableIndex]['total'] =
        ((tables[tableIndex]['total'] as double) - price * qty)
            .clamp(0.0, double.infinity);

    final newTotal = tables[tableIndex]['total'] as double;
    if ((tables[tableIndex]['discount'] as double) > newTotal) {
      tables[tableIndex]['discount'] = 0.0;
    }

    await KitchenService.to.removeTicketForItem(tableId: _id(tableIndex), itemName: name);
    orders.removeAt(orderIndex);
    _setOccupied(tableIndex);

    try {
      await _db.from('orders').delete().eq('id', orderId);
      await _syncTableHeader(tableIndex);
    } catch (e) {
      if (kDebugMode) print('[TableService] removeOrder error: $e');
    }
  }

  Future<void> decrementOrder(int tableIndex, int orderIndex) async {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    if (orderIndex >= orders.length) return;

    final order = orders[orderIndex];
    final qty = order['quantity'] as int;
    final price = order['price'] as double;
    final name = order['name'] as String;
    final orderId = order['id'] as int;

    if (qty <= 1) {
      await KitchenService.to.removeTicketForItem(tableId: _id(tableIndex), itemName: name);
      await removeOrder(tableIndex, orderIndex);
      return;
    }

    orders[orderIndex]['quantity'] = qty - 1;
    tables[tableIndex]['total'] =
        ((tables[tableIndex]['total'] as double) - price)
            .clamp(0.0, double.infinity);

    _setOccupied(tableIndex);

    KitchenService.to.addOrUpdateTicket(
      tableId: _id(tableIndex),
      tableName: tables[tableIndex]['name'] as String,
      itemName: name,
      quantity: qty - 1,
    );

    try {
      await _db
          .from('orders')
          .update({'quantity': qty - 1})
          .eq('id', orderId);
      await _syncTableHeader(tableIndex);
    } catch (e) {
      if (kDebugMode) print('[TableService] decrementOrder error: $e');
    }
  }

  // ── Clear / Payment ──────────────────────────────────────────

  Future<void> clearTable(int tableIndex) async {
    final tableId = _id(tableIndex);
    await KitchenService.to.removeTicketsForTable(tableId);

    tables[tableIndex]['orders'] = <Map<String, dynamic>>[];
    tables[tableIndex]['total'] = 0.0;
    tables[tableIndex]['isOccupied'] = false;
    tables[tableIndex]['discount'] = 0.0;
    tables[tableIndex]['staffEmail'] = '';
    tables.refresh();

    try {
      await _db.from('orders').delete().eq('table_id', tableId);
      await _syncTableHeader(tableIndex);
    } catch (e) {
      if (kDebugMode) print('[TableService] clearTable error: $e');
    }
  }

  Future<void> recordPayment(
    int tableIndex, {
    String paymentMethod = 'cash',
  }) async {
    final table = tables[tableIndex];
    final orders = List<Map<String, dynamic>>.from(
      table['orders'] as List<Map<String, dynamic>>,
    );
    final subtotal = table['total'] as double;
    final discount = (table['discount'] ?? 0.0) as double;
    final total = (subtotal - discount).clamp(0.0, double.infinity);
    final staffEmail = (table['staffEmail'] as String? ?? '');

    await SalesHistoryService.to.recordSale(
      tableName: table['name'] as String,
      items: orders,
      subtotal: subtotal,
      discount: discount,
      total: total,
      staffEmail: staffEmail,
      paymentMethod: paymentMethod,
    );

    await InventoryService.to.decrementForSale(orders);
    await clearTable(tableIndex);
  }

  // ── Discount ─────────────────────────────────────────────────

  Future<void> applyDiscount(int tableIndex, double discountPercentage) async {
    final currentTotal = tables[tableIndex]['total'] as double;
    final clamped = discountPercentage.clamp(0.0, 100.0);
    final discountAmount = currentTotal * (clamped / 100);
    tables[tableIndex]['discount'] = discountAmount;
    tables.refresh();

    try {
      await _db.from('tables').update({
        'discount': discountAmount,
      }).eq('id', _id(tableIndex));
    } catch (e) {
      if (kDebugMode) print('[TableService] applyDiscount error: $e');
    }
  }

  double getTotalWithDiscount(int tableIndex) {
    final total = tables[tableIndex]['total'] as double;
    final discount = (tables[tableIndex]['discount'] ?? 0.0) as double;
    return (total - discount).clamp(0.0, double.infinity);
  }

  double getDiscount(int tableIndex) =>
      (tables[tableIndex]['discount'] ?? 0.0) as double;

  List<Map<String, dynamic>> getOrders(int tableIndex) =>
      tables[tableIndex]['orders'] as List<Map<String, dynamic>>;

  double getTotal(int tableIndex) =>
      tables[tableIndex]['total'] as double;

  // ── Move orders between tables ────────────────────────────────

  Future<void> moveOrderToTable(
    int fromTableIndex,
    int toTableIndex,
    int orderIndex,
  ) async {
    final srcOrders = getOrders(fromTableIndex);
    if (orderIndex >= srcOrders.length) return;

    final order = srcOrders[orderIndex];
    final name = order['name'] as String;
    final price = order['price'] as double;
    final qty = order['quantity'] as int;
    final srcOrderId = order['id'] as int;
    final destTableId = _id(toTableIndex);

    final destOrders = getOrders(toTableIndex);
    final existingIdx = destOrders.indexWhere((o) => o['name'] == name);

    if (existingIdx != -1) {
      final newQty = (destOrders[existingIdx]['quantity'] as int) + qty;
      final destOrderId = destOrders[existingIdx]['id'] as int;
      destOrders[existingIdx]['quantity'] = newQty;

      KitchenService.to.addOrUpdateTicket(
        tableId: destTableId,
        tableName: tables[toTableIndex]['name'] as String,
        itemName: name,
        quantity: newQty,
      );

      try {
        await _db.from('orders').update({'quantity': newQty}).eq('id', destOrderId);
      } catch (e) {
        if (kDebugMode) print('[TableService] moveOrder dest-update error: $e');
      }
    } else {
      destOrders.add({'id': -1, 'name': name, 'quantity': qty, 'price': price});

      KitchenService.to.addOrUpdateTicket(
        tableId: destTableId,
        tableName: tables[toTableIndex]['name'] as String,
        itemName: name,
        quantity: qty,
      );

      try {
        // Re-parent the order row
        await _db.from('orders').update({'table_id': destTableId}).eq('id', srcOrderId);
        final idx = destOrders.indexWhere((o) => o['name'] == name && o['id'] == -1);
        if (idx != -1) destOrders[idx]['id'] = srcOrderId;
      } catch (e) {
        if (kDebugMode) print('[TableService] moveOrder reparent error: $e');
      }
    }

    tables[toTableIndex]['total'] =
        (tables[toTableIndex]['total'] as double) + price * qty;
    tables[toTableIndex]['isOccupied'] = true;

    tables[fromTableIndex]['total'] =
        ((tables[fromTableIndex]['total'] as double) - price * qty)
            .clamp(0.0, double.infinity);
    srcOrders.removeAt(orderIndex);
    tables[fromTableIndex]['isOccupied'] = srcOrders.isNotEmpty;

    final srcDiscount = (tables[fromTableIndex]['discount'] ?? 0.0) as double;
    if (srcDiscount > (tables[fromTableIndex]['total'] as double)) {
      tables[fromTableIndex]['discount'] = 0.0;
    }

    await KitchenService.to.removeTicketForItem(
      tableId: _id(fromTableIndex),
      itemName: name,
    );

    tables.refresh();

    try {
      await _syncTableHeader(fromTableIndex);
      await _syncTableHeader(toTableIndex);
    } catch (e) {
      if (kDebugMode) print('[TableService] moveOrder sync error: $e');
    }
  }

  Future<void> moveAllOrdersToTable(
    int fromTableIndex,
    int toTableIndex,
  ) async {
    final srcOrders =
        List<Map<String, dynamic>>.from(getOrders(fromTableIndex));
    final destOrders = getOrders(toTableIndex);
    final destTableId = _id(toTableIndex);
    double addedTotal = 0.0;

    for (final order in srcOrders) {
      final name = order['name'] as String;
      final price = order['price'] as double;
      final qty = order['quantity'] as int;
      final srcOrderId = order['id'] as int;
      addedTotal += price * qty;

      final existingIdx = destOrders.indexWhere((o) => o['name'] == name);
      if (existingIdx != -1) {
        final newQty = (destOrders[existingIdx]['quantity'] as int) + qty;
        final destOrderId = destOrders[existingIdx]['id'] as int;
        destOrders[existingIdx]['quantity'] = newQty;

        KitchenService.to.addOrUpdateTicket(
          tableId: destTableId,
          tableName: tables[toTableIndex]['name'] as String,
          itemName: name,
          quantity: newQty,
        );

        try {
          await _db
              .from('orders')
              .update({'quantity': newQty})
              .eq('id', destOrderId);
          // Delete the source duplicate
          await _db.from('orders').delete().eq('id', srcOrderId);
        } catch (e) {
          if (kDebugMode) print('[TableService] moveAll merge error: $e');
        }
      } else {
        destOrders.add({'id': srcOrderId, 'name': name, 'quantity': qty, 'price': price});

        KitchenService.to.addOrUpdateTicket(
          tableId: destTableId,
          tableName: tables[toTableIndex]['name'] as String,
          itemName: name,
          quantity: qty,
        );

        try {
          await _db
              .from('orders')
              .update({'table_id': destTableId})
              .eq('id', srcOrderId);
        } catch (e) {
          if (kDebugMode) print('[TableService] moveAll reparent error: $e');
        }
      }

      await KitchenService.to.removeTicketForItem(
        tableId: _id(fromTableIndex),
        itemName: name,
      );
    }

    tables[toTableIndex]['total'] =
        (tables[toTableIndex]['total'] as double) + addedTotal;
    tables[toTableIndex]['isOccupied'] = destOrders.isNotEmpty;

    tables[fromTableIndex]['orders'] = <Map<String, dynamic>>[];
    tables[fromTableIndex]['total'] = 0.0;
    tables[fromTableIndex]['discount'] = 0.0;
    tables[fromTableIndex]['isOccupied'] = false;
    tables[fromTableIndex]['staffEmail'] = '';

    tables.refresh();

    try {
      await _syncTableHeader(fromTableIndex);
      await _syncTableHeader(toTableIndex);
    } catch (e) {
      if (kDebugMode) print('[TableService] moveAll sync error: $e');
    }
  }
}
