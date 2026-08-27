import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/services/sales_history_service.dart';

/// Tenant-scoped current-account (deferred payment) records.
class CariService extends GetxService {
  static CariService get to => Get.find();

  final RxList<Map<String, dynamic>> accounts = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String? get _tenantId => _db.auth.currentUser?.id;

  int get openAccountCount => accounts.where((account) {
        final transactions =
            (account['transactions'] as List? ?? const []).cast<Map>();
        return transactions
            .any((transaction) => transaction['status'] != 'paid');
      }).length;

  Map<String, dynamic>? accountByName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final account in accounts) {
      if ((account['name'] as String? ?? '').trim().toLowerCase() ==
          normalized) {
        return account;
      }
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        refresh();
        _subscribe();
      } else if (data.event == AuthChangeEvent.signedOut) {
        accounts.clear();
        _channel?.unsubscribe();
        _channel = null;
      }
    });
    refresh();
    _subscribe();
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }

  Future<void> refresh() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    isLoading.value = true;
    try {
      final accountRows = await _db
          .from('cari_accounts')
          .select()
          .eq('tenant_id', tenantId)
          .order('name');
      final transactionRows = await _db
          .from('cari_transactions')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in transactionRows) {
        final transaction = Map<String, dynamic>.from(row);
        final accountId = transaction['account_id'] as String?;
        if (accountId == null) continue;
        (grouped[accountId] ??= []).add(transaction);
      }

      accounts.assignAll(accountRows.map((row) {
        final account = Map<String, dynamic>.from(row);
        final id = account['id'] as String;
        account['transactions'] = grouped[id] ?? <Map<String, dynamic>>[];
        return account;
      }));
    } catch (e) {
      if (kDebugMode) print('[CariService] refresh error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    final tenantId = _tenantId;
    if (tenantId == null) return;
    _channel = _db
        .channel('cari_changes_$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cari_accounts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cari_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  Future<Map<String, dynamic>?> createAccount(String name) async {
    final tenantId = _tenantId;
    final trimmed = name.trim();
    if (tenantId == null || trimmed.isEmpty) return null;
    try {
      final row = await _db
          .from('cari_accounts')
          .insert({'tenant_id': tenantId, 'name': trimmed})
          .select()
          .single();
      await refresh();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      if (kDebugMode) print('[CariService] createAccount error: $e');
      return null;
    }
  }

  Future<bool> sendTableToAccount({
    required String accountId,
    required String tableName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required String staffEmail,
  }) async {
    final tenantId = _tenantId;
    if (tenantId == null || items.isEmpty || total <= 0) return false;
    try {
      await _db.from('cari_transactions').insert({
        'tenant_id': tenantId,
        'account_id': accountId,
        'table_name': tableName,
        'items': items,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'staff_email': staffEmail,
        'status': 'open',
      });
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) print('[CariService] sendTableToAccount error: $e');
      return false;
    }
  }

  Future<bool> markPaid(
    Map<String, dynamic> transaction, {
    required String paymentMethod,
  }) async {
    final id = transaction['id'] as String?;
    final tenantId = _tenantId;
    if (id == null || tenantId == null || transaction['status'] == 'paid') {
      return false;
    }

    final items = (transaction['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final recorded = await SalesHistoryService.to.recordSale(
      tableName: transaction['table_name'] as String? ?? 'Cari Hesap',
      items: items,
      subtotal: (transaction['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (transaction['discount'] as num?)?.toDouble() ?? 0,
      total: (transaction['total'] as num?)?.toDouble() ?? 0,
      staffEmail: transaction['staff_email'] as String? ?? '',
      paymentMethod: 'cari_$paymentMethod',
    );
    if (!recorded) return false;

    try {
      await _db
          .from('cari_transactions')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toUtc().toIso8601String(),
            'payment_method': paymentMethod,
          })
          .eq('id', id)
          .eq('tenant_id', tenantId);
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) print('[CariService] markPaid error: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    final tenantId = _tenantId;
    if (tenantId == null) return false;
    try {
      await _db
          .from('cari_transactions')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) print('[CariService] deleteTransaction error: $e');
      return false;
    }
  }
}
