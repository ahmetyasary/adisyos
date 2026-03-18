import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KitchenService extends GetxService {
  static KitchenService get to => Get.find();

  final RxList<Map<String, dynamic>> tickets = <Map<String, dynamic>>[].obs;

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
          .from('kitchen_tickets')
          .select()
          .order('ordered_at');

      tickets.assignAll(rows.map(_rowToTicket).toList());
    } catch (e) {
      if (kDebugMode) print('[KitchenService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToTicket(Map<String, dynamic> row) => {
        'id': row['id'] as String,
        'tableId': row['table_id'] as int?,
        'tableName': row['table_name'] as String,
        'itemName': row['item_name'] as String,
        'quantity': row['quantity'] as int,
        'status': row['status'] as String,
        'orderedAt': row['ordered_at'] as String,
      };

  // ── Realtime subscription ────────────────────────────────────

  void _subscribeRealtime() {
    _channel = _db
        .channel('kitchen_tickets_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kitchen_tickets',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Mutations ────────────────────────────────────────────────

  Future<void> addOrUpdateTicket({
    required int tableId,
    required String tableName,
    required String itemName,
    required int quantity,
  }) async {
    try {
      final existingIdx = tickets.indexWhere(
        (t) =>
            t['tableId'] == tableId &&
            t['itemName'] == itemName &&
            t['status'] != 'ready',
      );

      if (existingIdx != -1) {
        final ticketId = tickets[existingIdx]['id'] as String;
        tickets[existingIdx]['quantity'] = quantity;
        tickets.refresh();
        await _db
            .from('kitchen_tickets')
            .update({'quantity': quantity})
            .eq('id', ticketId);
      } else {
        final row = await _db
            .from('kitchen_tickets')
            .insert({
              'table_id': tableId,
              'table_name': tableName,
              'item_name': itemName,
              'quantity': quantity,
              'status': 'pending',
            })
            .select()
            .single();

        tickets.add(_rowToTicket(row));
      }
    } catch (e) {
      if (kDebugMode) print('[KitchenService] addOrUpdateTicket error: $e');
    }
  }

  Future<void> advanceStatus(String ticketId) async {
    final idx = tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;

    final current = tickets[idx]['status'] as String;
    final next = current == 'pending'
        ? 'preparing'
        : current == 'preparing'
            ? 'ready'
            : null;
    if (next == null) return;

    tickets[idx]['status'] = next;
    tickets.refresh();

    try {
      await _db
          .from('kitchen_tickets')
          .update({'status': next})
          .eq('id', ticketId);
    } catch (e) {
      if (kDebugMode) print('[KitchenService] advanceStatus error: $e');
    }
  }

  Future<void> removeTicketsForTable(int tableId) async {
    tickets.removeWhere((t) => t['tableId'] == tableId);
    try {
      await _db
          .from('kitchen_tickets')
          .delete()
          .eq('table_id', tableId);
    } catch (e) {
      if (kDebugMode) print('[KitchenService] removeTicketsForTable error: $e');
    }
  }

  Future<void> removeTicketForItem({
    required int tableId,
    required String itemName,
  }) async {
    tickets.removeWhere(
      (t) => t['tableId'] == tableId && t['itemName'] == itemName,
    );
    try {
      await _db
          .from('kitchen_tickets')
          .delete()
          .eq('table_id', tableId)
          .eq('item_name', itemName);
    } catch (e) {
      if (kDebugMode) print('[KitchenService] removeTicketForItem error: $e');
    }
  }

  Future<void> clearReadyTickets() async {
    tickets.removeWhere((t) => t['status'] == 'ready');
    try {
      await _db.from('kitchen_tickets').delete().eq('status', 'ready');
    } catch (e) {
      if (kDebugMode) print('[KitchenService] clearReadyTickets error: $e');
    }
  }

  // ── Computed lists ───────────────────────────────────────────

  List<Map<String, dynamic>> get pendingTickets =>
      tickets.where((t) => t['status'] == 'pending').toList();

  List<Map<String, dynamic>> get preparingTickets =>
      tickets.where((t) => t['status'] == 'preparing').toList();

  List<Map<String, dynamic>> get readyTickets =>
      tickets.where((t) => t['status'] == 'ready').toList();
}
