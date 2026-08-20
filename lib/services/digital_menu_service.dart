import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-facing config for the public digital menu (QR → browser).
class DigitalMenuService extends GetxService {
  static DigitalMenuService get to => Get.find();

  final _db = Supabase.instance.client;

  final RxBool loading = false.obs;
  final RxBool saving = false.obs;
  final RxBool enabled = true.obs;
  final RxString token = ''.obs;
  final RxList<int> selectedMenuIds = <int>[].obs;

  /// Selected table for the QR currently shown in the admin UI (not persisted
  /// as a single global choice — each table gets its own link/QR).
  final RxnInt selectedTableId = RxnInt();

  String? get _tenantId => _db.auth.currentUser?.id;

  static const _pagesBase = 'https://menu.orderix.tr/';

  /// Public URL for [tableId] / [tableName]. Omitting both yields the generic
  /// menu link (no table context).
  String publicUrl({int? tableId, String? tableName}) {
    final t = token.value.trim();
    if (t.isEmpty) return '';
    final params = <String, String>{'t': t};
    if (tableId != null) params['table'] = '$tableId';
    final name = tableName?.trim() ?? '';
    if (name.isNotEmpty) params['name'] = name;
    return Uri.parse(_pagesBase).replace(queryParameters: params).toString();
  }

  /// Compact Code128 payload for printed stickers (future order binding).
  String barcodePayload({required int tableId}) {
    final t = token.value.trim();
    return 'OX:$t:$tableId';
  }

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        load();
      }
      if (data.event == AuthChangeEvent.signedOut) {
        token.value = '';
        selectedMenuIds.clear();
        selectedTableId.value = null;
        enabled.value = true;
      }
    });
    load();
  }

  Future<void> load() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    loading.value = true;
    try {
      final row = await _db
          .from('digital_menu_config')
          .select('token, menu_ids, enabled')
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (row == null) {
        final created = await _ensureRow(tenantId);
        token.value = created;
        selectedMenuIds.clear();
        enabled.value = true;
        return;
      }

      token.value = (row['token'] as String?) ?? '';
      enabled.value = (row['enabled'] as bool?) ?? true;
      final ids = row['menu_ids'];
      if (ids is List) {
        selectedMenuIds.assignAll(
          ids.map((e) => (e as num).toInt()).toList(),
        );
      } else {
        selectedMenuIds.clear();
      }
      if (token.value.isEmpty) {
        token.value = await _ensureRow(tenantId);
      }
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuService] load error: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<String> _ensureRow(String tenantId) async {
    final newToken = _randomToken();
    try {
      await _db.from('digital_menu_config').upsert({
        'tenant_id': tenantId,
        'token': newToken,
        'menu_ids': <int>[],
        'enabled': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return newToken;
    } catch (e) {
      // Race: another device may have inserted. Re-read.
      if (kDebugMode) print('[DigitalMenuService] ensure upsert: $e');
      final row = await _db
          .from('digital_menu_config')
          .select('token')
          .eq('tenant_id', tenantId)
          .maybeSingle();
      return (row?['token'] as String?) ?? newToken;
    }
  }

  void toggleMenu(int menuId) {
    if (selectedMenuIds.contains(menuId)) {
      selectedMenuIds.remove(menuId);
    } else {
      selectedMenuIds.add(menuId);
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await save();
  }

  Future<bool> save() async {
    final tenantId = _tenantId;
    if (tenantId == null) return false;
    saving.value = true;
    try {
      var t = token.value.trim();
      if (t.isEmpty) t = await _ensureRow(tenantId);
      await _db.from('digital_menu_config').upsert({
        'tenant_id': tenantId,
        'token': t,
        'menu_ids': selectedMenuIds.toList(),
        'enabled': enabled.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      token.value = t;
      return true;
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuService] save error: $e');
      return false;
    } finally {
      saving.value = false;
    }
  }

  /// Rotates the public token (invalidates old QR links).
  Future<bool> regenerateToken() async {
    final tenantId = _tenantId;
    if (tenantId == null) return false;
    final newToken = _randomToken();
    saving.value = true;
    try {
      await _db.from('digital_menu_config').upsert({
        'tenant_id': tenantId,
        'token': newToken,
        'menu_ids': selectedMenuIds.toList(),
        'enabled': enabled.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      token.value = newToken;
      return true;
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuService] regenerate error: $e');
      return false;
    } finally {
      saving.value = false;
    }
  }

  String _randomToken() {
    const chars = 'abcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
