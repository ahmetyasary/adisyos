import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KitchenService extends GetxService {
  static KitchenService get to => Get.find();

  final RxList<Map<String, dynamic>> tickets = <Map<String, dynamic>>[].obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get _tenantId => _db.auth.currentUser!.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _load();
    });
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

  void _err(String tag, Object e) {
    if (kDebugMode) print('[KitchenService] $tag error: $e');
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

        // Fire-and-forget DB update.
        _db.from('kitchen_tickets')
            .update({'quantity': quantity})
            .eq('id', ticketId)
            .catchError((e) => _err('addOrUpdateTicket(update)', e));
      } else {
        // Insert: need real id — resolve optimistically with temp then patch.
        final now = DateTime.now().toIso8601String();
        final tempId = 'tmp_${now}_$itemName';
        tickets.add({
          'id': tempId,
          'tableId': tableId,
          'tableName': tableName,
          'itemName': itemName,
          'quantity': quantity,
          'status': 'pending',
          'orderedAt': now,
        });

        _db.from('kitchen_tickets')
            .insert({
              'table_id': tableId,
              'table_name': tableName,
              'item_name': itemName,
              'quantity': quantity,
              'status': 'pending',
              'tenant_id': _tenantId,
            })
            .select()
            .single()
            .then((row) {
              final idx = tickets.indexWhere((t) => t['id'] == tempId);
              if (idx != -1) {
                tickets[idx] = _rowToTicket(row);
                tickets.refresh();
              }
            }, onError: (e) => _err('addOrUpdateTicket(insert)', e));
      }
    } catch (e) {
      _err('addOrUpdateTicket', e);
    }
  }

  void advanceStatus(String ticketId) {
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

    _db.from('kitchen_tickets')
        .update({'status': next})
        .eq('id', ticketId)
        .catchError((e) => _err('advanceStatus', e));
  }

  Future<void> removeTicketsForTable(int tableId) async {
    tickets.removeWhere((t) => t['tableId'] == tableId);
    _db.from('kitchen_tickets')
        .delete()
        .eq('table_id', tableId)
        .catchError((e) => _err('removeTicketsForTable', e));
  }

  Future<void> removeTicketForItem({
    required int tableId,
    required String itemName,
  }) async {
    tickets.removeWhere(
      (t) => t['tableId'] == tableId && t['itemName'] == itemName,
    );
    _db.from('kitchen_tickets')
        .delete()
        .eq('table_id', tableId)
        .eq('item_name', itemName)
        .catchError((e) => _err('removeTicketForItem', e));
  }

  void clearReadyTickets() {
    tickets.removeWhere((t) => t['status'] == 'ready');
    _db.from('kitchen_tickets')
        .delete()
        .eq('status', 'ready')
        .catchError((e) => _err('clearReadyTickets', e));
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  // ── Computed lists ───────────────────────────────────────────

  List<Map<String, dynamic>> get pendingTickets =>
      tickets.where((t) => t['status'] == 'pending').toList();

  List<Map<String, dynamic>> get preparingTickets =>
      tickets.where((t) => t['status'] == 'preparing').toList();

  List<Map<String, dynamic>> get readyTickets =>
      tickets.where((t) => t['status'] == 'ready').toList();
}
