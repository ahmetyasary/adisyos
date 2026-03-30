import 'dart:async';
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

  /// Partial payments per table — reactive, DB-backed, realtime across devices.
  final partialPaymentsByTable =
      <int, List<Map<String, dynamic>>>{}.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;
  RealtimeChannel? _partialChannel;
  Timer? _debounce;
  int _loadSeq = 0;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _load().then((_) => _loadAllPartialPayments());
      }
    });
    _init();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    if (_channel != null) _db.removeChannel(_channel!);
    if (_partialChannel != null) _db.removeChannel(_partialChannel!);
    super.onClose();
  }

  Future<void> _init() async {
    await _load();
    await _loadAllPartialPayments();
    _subscribeRealtime();
  }

  void _debouncedLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load());
  }

  // ── Load ────────────────────────────────────────────────────

  Future<void> _load() async {
    final seq = ++_loadSeq;
    try {
      final rows = await _db
          .from('tables')
          .select('*, orders(*)')
          .order('id');
      if (seq != _loadSeq) return;
      tables.assignAll(rows.map(_rowToTable).toList());
    } catch (e) {
      _err('load', e);
    }
  }

  Map<String, dynamic> _rowToTable(Map<String, dynamic> row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
        'isOccupied': row['is_occupied'] as bool,
        'total': (row['total'] as num).toDouble(),
        'discount': (row['discount'] as num).toDouble(),
        'staffEmail': (row['staff_email'] as String?) ?? '',
        'sectionId': row['section_id'] as String?,
        'orders': (row['orders'] as List)
            .map((o) => <String, dynamic>{
                  'id': o['id'] as int,
                  'name': o['name'] as String,
                  'quantity': o['quantity'] as int,
                  'price': (o['price'] as num).toDouble(),
                })
            .toList(),
      };

  // ── Partial payments — DB-backed realtime ────────────────────

  Future<void> _loadAllPartialPayments() async {
    try {
      final rows = await _db
          .from('table_partial_payments')
          .select()
          .order('created_at');
      final map = <int, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final tableId = row['table_id'] as int;
        final idx = tables.indexWhere((t) => t['id'] == tableId);
        if (idx == -1) continue;
        map.putIfAbsent(idx, () => []).add({
          'name': row['item_name'] as String,
          'qty': row['qty'] as int,
          'total': (row['total'] as num).toDouble(),
          'method': row['method'] as String,
        });
      }
      partialPaymentsByTable.assignAll(map);
    } catch (e) {
      // Table may not exist yet — fail silently and use in-memory only.
      if (kDebugMode) print('[TableService] loadAllPartialPayments: $e');
    }
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  // ── Realtime ─────────────────────────────────────────────────

  void _subscribeRealtime() {
    // Critical channel — tables + orders realtime (must never fail).
    _channel = _db
        .channel('tables_and_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tables',
          callback: (_) => _debouncedLoad(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _debouncedLoad(),
        )
        .subscribe();

    // Separate channel for partial payments — isolated so a missing table
    // cannot break the main orders channel.
    _partialChannel = _db
        .channel('table_partial_payments_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'table_partial_payments',
          callback: (_) => _loadAllPartialPayments(),
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

  void _err(String tag, Object e) {
    if (kDebugMode) print('[TableService] $tag error: $e');
  }

  // ── Table CRUD ───────────────────────────────────────────────

  Future<void> addTable(String name, {String? sectionId}) async {
    try {
      final row = await _db
          .from('tables')
          .insert({
            'name': name,
            'is_occupied': false,
            'total': 0.0,
            'discount': 0.0,
            'staff_email': '',
            if (sectionId != null) 'section_id': sectionId,
          })
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
      _err('addTable', e);
    }
  }

  Future<void> removeTable(int index) async {
    final tableId = _id(index);
    await KitchenService.to.removeTicketsForTable(tableId);
    tables.removeAt(index);
    _db.from('tables')
        .delete()
        .eq('id', tableId)
        .catchError((e) => _err('removeTable', e));
  }

  void updateTableName(int index, String newName) {
    tables[index]['name'] = newName;
    tables.refresh();
    _db.from('tables')
        .update({'name': newName})
        .eq('id', _id(index))
        .catchError((e) => _err('updateTableName', e));
  }

  void toggleTableStatus(int index) {
    tables[index]['isOccupied'] = !(tables[index]['isOccupied'] as bool);
    tables.refresh();
    _db.from('tables').update({
      'is_occupied': tables[index]['isOccupied'] as bool,
    }).eq('id', _id(index))
        .catchError((e) => _err('toggleTableStatus', e));
  }

  void _setOccupied(int tableIndex) {
    final orders = tables[tableIndex]['orders'] as List;
    tables[tableIndex]['isOccupied'] = orders.isNotEmpty;
    tables.refresh();
  }

  // ── Order mutations ──────────────────────────────────────────

  void addOrder(int tableIndex, String name, double price) {
    final tableId = _id(tableIndex);
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    final existingIdx = orders.indexWhere((o) => o['name'] == name);
    _assignStaff(tableIndex);

    if (existingIdx != -1) {
      final newQty = (orders[existingIdx]['quantity'] as int) + 1;
      final orderId = orders[existingIdx]['id'] as int;
      orders[existingIdx]['quantity'] = newQty;
      tables[tableIndex]['total'] =
          (tables[tableIndex]['total'] as double) + price;
      _setOccupied(tableIndex);
      KitchenService.to.addOrUpdateTicket(
        tableId: tableId,
        tableName: tables[tableIndex]['name'] as String,
        itemName: name,
        quantity: newQty,
      );
      InventoryService.to.decrementForSale([{'name': name, 'quantity': 1, 'price': price}]);
      Future.wait([
        _db.from('orders').update({'quantity': newQty}).eq('id', orderId),
        _syncTableHeader(tableIndex),
      ]).catchError((e) => _err('addOrder(update)', e));
    } else {
      orders.add(<String, dynamic>{
        'id': -1,
        'name': name,
        'quantity': 1,
        'price': price,
      });
      tables[tableIndex]['total'] =
          (tables[tableIndex]['total'] as double) + price;
      _setOccupied(tableIndex);
      KitchenService.to.addOrUpdateTicket(
        tableId: tableId,
        tableName: tables[tableIndex]['name'] as String,
        itemName: name,
        quantity: 1,
      );
      InventoryService.to.decrementForSale([{'name': name, 'quantity': 1, 'price': price}]);
      _db.from('orders')
          .insert({
            'table_id': tableId,
            'name': name,
            'quantity': 1,
            'price': price,
          })
          .select()
          .single()
          .then((row) {
            final idx =
                orders.indexWhere((o) => o['name'] == name && o['id'] == -1);
            if (idx != -1) orders[idx]['id'] = row['id'] as int;
            return _syncTableHeader(tableIndex);
          })
          .catchError((e) => _err('addOrder(insert)', e));
    }
  }

  void removeOrder(int tableIndex, int orderIndex) {
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
    orders.removeAt(orderIndex);
    _setOccupied(tableIndex);
    KitchenService.to
        .removeTicketForItem(tableId: _id(tableIndex), itemName: name);
    InventoryService.to.incrementForCancellation([{'name': name, 'quantity': qty, 'price': price}]);
    Future.wait([
      _db.from('orders').delete().eq('id', orderId),
      _syncTableHeader(tableIndex),
    ]).catchError((e) => _err('removeOrder', e));
  }

  void decrementOrder(int tableIndex, int orderIndex) {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    if (orderIndex >= orders.length) return;
    final order = orders[orderIndex];
    final qty = order['quantity'] as int;
    final price = order['price'] as double;
    final name = order['name'] as String;
    final orderId = order['id'] as int;
    if (qty <= 1) {
      removeOrder(tableIndex, orderIndex);
      return;
    }
    orders[orderIndex]['quantity'] = qty - 1;
    tables[tableIndex]['total'] =
        ((tables[tableIndex]['total'] as double) - price)
            .clamp(0.0, double.infinity);
    _setOccupied(tableIndex);
    InventoryService.to.incrementForCancellation([{'name': name, 'quantity': 1, 'price': price}]);
    KitchenService.to.addOrUpdateTicket(
      tableId: _id(tableIndex),
      tableName: tables[tableIndex]['name'] as String,
      itemName: name,
      quantity: qty - 1,
    );
    Future.wait([
      _db.from('orders').update({'quantity': qty - 1}).eq('id', orderId),
      _syncTableHeader(tableIndex),
    ]).catchError((e) => _err('decrementOrder', e));
  }

  // ── Clear / Payment ──────────────────────────────────────────

  void clearTable(int tableIndex) {
    clearPartialPayments(tableIndex);
    final tableId = _id(tableIndex);
    final orders = List<Map<String, dynamic>>.from(
      tables[tableIndex]['orders'] as List<Map<String, dynamic>>,
    );
    if (orders.isNotEmpty) {
      InventoryService.to.incrementForCancellation(orders);
    }
    KitchenService.to.removeTicketsForTable(tableId);
    tables[tableIndex]['orders'] = <Map<String, dynamic>>[];
    tables[tableIndex]['total'] = 0.0;
    tables[tableIndex]['isOccupied'] = false;
    tables[tableIndex]['discount'] = 0.0;
    tables[tableIndex]['staffEmail'] = '';
    tables.refresh();
    Future.wait([
      _db.from('orders').delete().eq('table_id', tableId),
      _syncTableHeader(tableIndex),
    ]).catchError((e) => _err('clearTable', e));
  }

  void recordPayment(int tableIndex, {String paymentMethod = 'cash'}) {
    final table = tables[tableIndex];
    final orders = List<Map<String, dynamic>>.from(
      table['orders'] as List<Map<String, dynamic>>,
    );
    final subtotal = table['total'] as double;
    final discount = (table['discount'] ?? 0.0) as double;
    final total = (subtotal - discount).clamp(0.0, double.infinity);
    final staffEmail = (table['staffEmail'] as String? ?? '');
    final tableName = table['name'] as String;
    clearTable(tableIndex);
    SalesHistoryService.to.recordSale(
      tableName: tableName,
      items: orders,
      subtotal: subtotal,
      discount: discount,
      total: total,
      staffEmail: staffEmail,
      paymentMethod: paymentMethod,
    ).ignore();
  }

  /// Pay [units] units of [itemName] — optimistic in-memory update, DB in background.
  Future<void> recordPartialPaymentUnits(
    int tableIndex,
    String itemName,
    int units, {
    String paymentMethod = 'cash',
  }) async {
    if (tableIndex >= tables.length) return;
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    final idx = orders.indexWhere((o) => o['name'] == itemName);
    if (idx == -1) return;
    final order = orders[idx];
    final price = order['price'] as double;
    final currentQty = order['quantity'] as int;
    final orderId = order['id'] as int;
    final payUnits = units.clamp(1, currentQty);
    final newQty = currentQty - payUnits;
    final tableName = tables[tableIndex]['name'] as String;
    final staffEmail = (tables[tableIndex]['staffEmail'] as String? ?? '');
    final tableId = _id(tableIndex);

    // ── Instant in-memory update ─────────────────────────────────
    tables[tableIndex]['total'] =
        ((tables[tableIndex]['total'] as double) - price * payUnits)
            .clamp(0.0, double.infinity);
    if (newQty <= 0) {
      orders.removeAt(idx);
      KitchenService.to
          .removeTicketForItem(tableId: tableId, itemName: itemName);
    } else {
      orders[idx]['quantity'] = newQty;
      KitchenService.to.addOrUpdateTicket(
        tableId: tableId,
        tableName: tableName,
        itemName: itemName,
        quantity: newQty,
      );
    }
    _setOccupied(tableIndex);

    // ── Background DB writes ─────────────────────────────────────
    final saleItems = [
      {'name': itemName, 'quantity': payUnits, 'price': price}
    ];
    final saleTotal = price * payUnits;
    SalesHistoryService.to.recordSale(
      tableName: tableName,
      items: saleItems,
      subtotal: saleTotal,
      discount: 0.0,
      total: saleTotal,
      staffEmail: staffEmail,
      paymentMethod: paymentMethod,
    ).ignore();
    final orderFuture = newQty <= 0
        ? _db.from('orders').delete().eq('id', orderId)
        : _db.from('orders').update({'quantity': newQty}).eq('id', orderId);
    orderFuture
        .then((_) => _syncTableHeader(tableIndex))
        .catchError((e) => _err('recordPartialPaymentUnits', e));
  }

  // ── Partial payment records — DB-backed, realtime ────────────

  void addPartialPaymentRecord(int tableIndex, Map<String, dynamic> record) {
    (partialPaymentsByTable[tableIndex] ??= []).add(record);
    partialPaymentsByTable.refresh();
    // Persist to DB so other devices see it instantly.
    _db.from('table_partial_payments').insert({
      'table_id': _id(tableIndex),
      'item_name': record['name'] as String,
      'qty': record['qty'] as int,
      'total': record['total'] as double,
      'method': record['method'] as String,
    }).catchError((e) => _err('addPartialPaymentRecord', e));
  }

  List<Map<String, dynamic>> getPartialPayments(int tableIndex) =>
      List.from(partialPaymentsByTable[tableIndex] ?? []);

  void clearPartialPayments(int tableIndex) {
    final tableId = _id(tableIndex);
    partialPaymentsByTable.remove(tableIndex);
    partialPaymentsByTable.refresh();
    _db.from('table_partial_payments')
        .delete()
        .eq('table_id', tableId)
        .catchError((e) => _err('clearPartialPayments', e));
  }

  // ── Discount ─────────────────────────────────────────────────

  void applyDiscount(int tableIndex, double discountPercentage) {
    final currentTotal = tables[tableIndex]['total'] as double;
    final clamped = discountPercentage.clamp(0.0, 100.0);
    final discountAmount = currentTotal * (clamped / 100);
    tables[tableIndex]['discount'] = discountAmount;
    tables.refresh();
    _db.from('tables').update({
      'discount': discountAmount,
    }).eq('id', _id(tableIndex))
        .catchError((e) => _err('applyDiscount', e));
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

  double getTotal(int tableIndex) => tables[tableIndex]['total'] as double;

  // ── Move orders between tables ────────────────────────────────

  void moveOrderToTable(
    int fromTableIndex,
    int toTableIndex,
    int orderIndex,
  ) {
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
      _db.from('orders')
          .update({'quantity': newQty})
          .eq('id', destOrderId)
          .catchError((e) => _err('moveOrder dest-update', e));
    } else {
      destOrders.add({'id': -1, 'name': name, 'quantity': qty, 'price': price});
      KitchenService.to.addOrUpdateTicket(
        tableId: destTableId,
        tableName: tables[toTableIndex]['name'] as String,
        itemName: name,
        quantity: qty,
      );
      _db.from('orders')
          .update({'table_id': destTableId})
          .eq('id', srcOrderId)
          .then((_) {
            final idx = destOrders
                .indexWhere((o) => o['name'] == name && o['id'] == -1);
            if (idx != -1) destOrders[idx]['id'] = srcOrderId;
          })
          .catchError((e) => _err('moveOrder reparent', e));
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
    KitchenService.to.removeTicketForItem(
      tableId: _id(fromTableIndex),
      itemName: name,
    );
    tables.refresh();
    Future.wait([
      _syncTableHeader(fromTableIndex),
      _syncTableHeader(toTableIndex),
    ]).catchError((e) => _err('moveOrder sync', e));
  }

  void moveAllOrdersToTable(int fromTableIndex, int toTableIndex) {
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
        Future.wait([
          _db.from('orders').update({'quantity': newQty}).eq('id', destOrderId),
          _db.from('orders').delete().eq('id', srcOrderId),
        ]).catchError((e) => _err('moveAll merge', e));
      } else {
        destOrders.add(
            {'id': srcOrderId, 'name': name, 'quantity': qty, 'price': price});
        KitchenService.to.addOrUpdateTicket(
          tableId: destTableId,
          tableName: tables[toTableIndex]['name'] as String,
          itemName: name,
          quantity: qty,
        );
        _db.from('orders')
            .update({'table_id': destTableId})
            .eq('id', srcOrderId)
            .catchError((e) => _err('moveAll reparent', e));
      }
      KitchenService.to.removeTicketForItem(
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
    Future.wait([
      _syncTableHeader(fromTableIndex),
      _syncTableHeader(toTableIndex),
    ]).catchError((e) => _err('moveAll sync', e));
  }
}
