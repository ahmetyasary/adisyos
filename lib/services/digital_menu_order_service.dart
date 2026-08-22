import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/services/local_notify_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/utils/app_haptics.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/app_toast.dart';

/// Pending customer orders from the public digital menu (QR).
class DigitalMenuOrderService extends GetxService {
  static DigitalMenuOrderService get to => Get.find();

  final RxList<Map<String, dynamic>> pending = <Map<String, dynamic>>[].obs;
  final RxBool loading = false.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  /// Ids already seen — used to detect newly arrived pending orders.
  final Set<String> _knownIds = <String>{};
  bool _hydrated = false;

  String? get _tenantId => _db.auth.currentUser?.id;

  int get pendingCount => pending.length;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        refresh();
        _resubscribe();
      }
      if (data.event == AuthChangeEvent.signedOut) {
        pending.clear();
        _knownIds.clear();
        _hydrated = false;
        _unsubscribe();
      }
    });
    refresh();
    _subscribe();
  }

  @override
  void onClose() {
    _unsubscribe();
    super.onClose();
  }

  void _subscribe() {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    _channel = _db
        .channel('digital_menu_orders_$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'digital_menu_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (_) => refresh(notifyNew: true),
        )
        .subscribe();
  }

  void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void _resubscribe() {
    _unsubscribe();
    _subscribe();
  }

  /// Call when the app returns from background / sleep.
  Future<void> onAppResumed() async {
    _resubscribe();
    await refresh(notifyNew: true);
  }

  Future<void> refresh({bool notifyNew = false}) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    loading.value = true;
    try {
      final rows = await _db
          .from('digital_menu_orders')
          .select()
          .eq('tenant_id', tenantId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final mapped = (rows as List)
          .map((e) => _mapRow(Map<String, dynamic>.from(e)))
          .toList();

      final arrived = <Map<String, dynamic>>[];
      if (_hydrated && notifyNew) {
        for (final o in mapped) {
          final id = o['id'] as String;
          if (!_knownIds.contains(id)) arrived.add(o);
        }
      }

      pending.assignAll(mapped);
      _knownIds
        ..clear()
        ..addAll(mapped.map((o) => o['id'] as String));

      if (arrived.isNotEmpty) {
        await _alertNewOrders(arrived);
      }
      _hydrated = true;
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuOrderService] refresh: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> _alertNewOrders(List<Map<String, dynamic>> orders) async {
    final n = orders.length;
    final first = orders.first;
    final table = (first['tableName'] as String?)?.trim();
    final title = 'new_order'.tr;
    final body = n == 1
        ? (table != null && table.isNotEmpty
            ? '$table · ${'new_order_message'.tr}'
            : 'new_order_message'.tr)
        : '$n ${'new_orders_plural'.tr}';

    AppToast.warning(body, title: title);
    await AppHaptics.orderArrived();

    if (Get.isRegistered<LocalNotifyService>()) {
      await LocalNotifyService.to.showOrderAlert(title: title, body: body);
    }
  }

  Map<String, dynamic> _mapRow(Map<String, dynamic> row) {
    final rawItems = row['items'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is! Map) continue;
        items.add({
          'id': it['id'],
          'name': (it['name'] as String?) ?? '',
          'price': (it['price'] as num?)?.toDouble() ?? 0.0,
          'qty': (it['qty'] as num?)?.toInt() ??
              (it['quantity'] as num?)?.toInt() ??
              1,
        });
      }
    }
    return {
      'id': row['id'] as String,
      'tableId': (row['table_id'] as num).toInt(),
      'tableName': (row['table_name'] as String?) ?? '',
      'items': items,
      'note': (row['customer_note'] as String?) ?? '',
      'createdAt': row['created_at'] as String?,
    };
  }

  bool isTableOccupied(int tableId) {
    final tables = TableService.to.tables;
    for (final t in tables) {
      if (t['id'] == tableId) {
        final orders = t['orders'] as List? ?? const [];
        return orders.isNotEmpty || t['isOccupied'] == true;
      }
    }
    return false;
  }

  int _tableIndex(int tableId) =>
      TableService.to.tables.indexWhere((t) => t['id'] == tableId);

  /// Approves a pending QR order into the live table.
  /// Returns a short status message, or null if cancelled / failed.
  Future<String?> approve(String orderId) async {
    Map<String, dynamic>? order;
    for (final o in pending) {
      if (o['id'] == orderId) {
        order = o;
        break;
      }
    }
    if (order == null) return 'Sipariş bulunamadı';

    final tableId = order['tableId'] as int;
    final ti = _tableIndex(tableId);
    if (ti < 0) return 'Masa bulunamadı';

    if (isTableOccupied(tableId)) {
      final confirmed = await AppDialog.confirm(
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: const Color(0xFFFF9500),
        title: 'Masa dolu',
        message:
            '“${order['tableName']}” masasında açık adisyon var.\nYine de bu siparişi masaya eklemek istiyor musunuz?',
        confirmText: 'Ekle',
        cancelText: 'Vazgeç',
      );
      if (!confirmed) return null;
    }

    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    for (final it in items) {
      final name = (it['name'] as String?) ?? '';
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['qty'] as num?)?.toInt() ?? 1;
      if (name.isEmpty) continue;
      for (var i = 0; i < qty; i++) {
        TableService.to.addOrder(ti, name, price);
      }
    }

    final note = (order['note'] as String?)?.trim() ?? '';
    if (note.isNotEmpty) {
      TableService.to.addOrder(ti, 'İstek: $note', 0);
    }

    await _delete(orderId);
    return 'Sipariş masaya aktarıldı';
  }

  Future<String?> reject(String orderId) async {
    await _delete(orderId);
    return 'Sipariş reddedildi';
  }

  Future<void> _delete(String orderId) async {
    pending.removeWhere((o) => o['id'] == orderId);
    _knownIds.remove(orderId);
    try {
      await _db.from('digital_menu_orders').delete().eq('id', orderId);
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuOrderService] delete: $e');
      await refresh();
    }
  }
}
