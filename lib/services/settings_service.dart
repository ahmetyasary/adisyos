import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  // Reactive value — read inside Obx to subscribe to changes
  static String get cs => SettingsService.to.currencySymbol.value;

  final RxString companyName      = ''.obs;
  final RxString currencySymbol   = '₺'.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get _tenantId => _db.auth.currentUser!.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _load();
        _resubscribeRealtime(); // re-auth ensures Postgres Changes events are delivered
      }
      if (data.event == AuthChangeEvent.signedOut) {
        currencySymbol.value = '₺';
        companyName.value = '';
      }
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
        .channel('settings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_settings',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  void _resubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribeRealtime();
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      final rows = await _db.from('app_settings').select();
      for (final row in rows) {
        switch (row['key'] as String?) {
          case 'company_name':
            companyName.value = row['value'] as String? ?? '';
          case 'currency_symbol':
            currencySymbol.value = row['value'] as String? ?? '₺';
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SettingsService] load error: $e');
    }
  }

  Future<void> save({String? newCompanyName}) async {
    if (newCompanyName == null) return;
    companyName.value = newCompanyName;
    try {
      await _db.from('app_settings').upsert([
        {'key': 'company_name', 'value': newCompanyName, 'tenant_id': _tenantId},
      ], onConflict: 'key,tenant_id');
    } catch (e) {
      if (kDebugMode) print('[SettingsService] save error: $e');
    }
  }

  Future<void> setCurrency(String symbol) async {
    currencySymbol.value = symbol;
    try {
      await _db.from('app_settings').upsert([
        {'key': 'currency_symbol', 'value': symbol, 'tenant_id': _tenantId},
      ], onConflict: 'key,tenant_id');
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setCurrency error: $e');
    }
  }
}
