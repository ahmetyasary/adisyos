import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  final RxString companyName = ''.obs;

  final _db = Supabase.instance.client;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

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
