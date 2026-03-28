import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  final RxString companyName = ''.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

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
        .channel('settings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_settings',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      final rows = await _db.from('app_settings').select();
      for (final row in rows) {
        if (row['key'] == 'company_name') {
          companyName.value = row['value'] as String? ?? '';
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
        {'key': 'company_name', 'value': newCompanyName},
      ]);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] save error: $e');
    }
  }
}
