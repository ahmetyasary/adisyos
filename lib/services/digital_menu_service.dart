import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-facing config for the public digital menu (QR → browser).
///
/// The share token is account-scoped: regenerating on iPad updates iPhone (and
/// vice versa) via Realtime so every device shows the same link.
class DigitalMenuService extends GetxService {
  static DigitalMenuService get to => Get.find();

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _noticeTimer;

  /// True while this device is writing — skip "remote update" UI for echoes.
  bool _localWrite = false;

  final RxBool loading = false.obs;
  final RxBool saving = false.obs;
  final RxBool enabled = true.obs;
  final RxString token = ''.obs;
  /// Public menu appearance: `system` | `light` | `dark`.
  final RxString themeMode = 'system'.obs;
  final RxList<int> selectedMenuIds = <int>[].obs;

  /// Brief banner text after another device changes the link / config.
  final RxString syncNotice = ''.obs;

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
        _resubscribeRealtime();
      }
      if (data.event == AuthChangeEvent.signedOut) {
        _unsubscribeRealtime();
        token.value = '';
        selectedMenuIds.clear();
        selectedTableId.value = null;
        enabled.value = true;
        themeMode.value = 'system';
        syncNotice.value = '';
      }
    });
    load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _noticeTimer?.cancel();
    _unsubscribeRealtime();
    super.onClose();
  }

  void _subscribeRealtime() {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    _channel = _db
        .channel('digital_menu_config_$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'digital_menu_config',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) {
            if (_localWrite) return;
            final row = payload.newRecord;
            if (row.isEmpty) return;
            _applyRemoteRow(Map<String, dynamic>.from(row));
          },
        )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void _resubscribeRealtime() {
    _unsubscribeRealtime();
    _subscribeRealtime();
  }

  void _applyRemoteRow(Map<String, dynamic> row) {
    final nextToken = (row['token'] as String?) ?? '';
    final tokenChanged =
        nextToken.isNotEmpty && nextToken != token.value.trim();
    final nextEnabled = (row['enabled'] as bool?) ?? true;
    final nextTheme = _sanitizeThemeMode(row['theme_mode'] as String?);
    final ids = row['menu_ids'];
    final nextIds = ids is List
        ? ids.map((e) => (e as num).toInt()).toList()
        : <int>[];

    if (nextToken.isNotEmpty) token.value = nextToken;
    enabled.value = nextEnabled;
    themeMode.value = nextTheme;
    selectedMenuIds.assignAll(nextIds);

    if (tokenChanged) {
      _showSyncNotice('Link değiştirildi, güncelleniyor…');
    } else {
      _showSyncNotice('Dijital menü başka cihazda güncellendi');
    }
  }

  void _showSyncNotice(String message) {
    syncNotice.value = message;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (syncNotice.value == message) syncNotice.value = '';
    });
  }

  Future<void> load() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    loading.value = true;
    try {
      Map<String, dynamic>? row;
      try {
        row = await _db
            .from('digital_menu_config')
            .select('token, menu_ids, enabled, theme_mode')
            .eq('tenant_id', tenantId)
            .maybeSingle();
      } catch (_) {
        row = await _db
            .from('digital_menu_config')
            .select('token, menu_ids, enabled')
            .eq('tenant_id', tenantId)
            .maybeSingle();
      }

      if (row == null) {
        final created = await _ensureRow(tenantId);
        token.value = created;
        selectedMenuIds.clear();
        enabled.value = true;
        themeMode.value = 'system';
        return;
      }

      token.value = (row['token'] as String?) ?? '';
      enabled.value = (row['enabled'] as bool?) ?? true;
      themeMode.value = _sanitizeThemeMode(row['theme_mode'] as String?);
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
      await _withLocalWrite(() async {
        await _db.from('digital_menu_config').upsert({
          'tenant_id': tenantId,
          'token': newToken,
          'menu_ids': <int>[],
          'enabled': true,
          'theme_mode': 'system',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      });
      return newToken;
    } catch (e) {
      if (kDebugMode) print('[DigitalMenuService] ensure upsert: $e');
      final row = await _db
          .from('digital_menu_config')
          .select('token')
          .eq('tenant_id', tenantId)
          .maybeSingle();
      return (row?['token'] as String?) ?? newToken;
    }
  }

  Future<T> _withLocalWrite<T>(Future<T> Function() action) async {
    _localWrite = true;
    try {
      return await action();
    } finally {
      // Allow realtime echo to settle before accepting remote events again.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        _localWrite = false;
      });
    }
  }

  Future<bool> toggleMenu(int menuId) async {
    if (selectedMenuIds.contains(menuId)) {
      selectedMenuIds.remove(menuId);
    } else {
      selectedMenuIds.add(menuId);
    }
    return save();
  }

  /// Updates the order of the categories that are currently published.
  /// Unchecked categories are intentionally excluded from this list.
  Future<bool> setMenuOrder(Iterable<int> ids) async {
    final selected = selectedMenuIds.toSet();
    final next = ids.where(selected.contains).toList();
    // Never let a reorder gesture accidentally uncheck a category.
    next.addAll(selected.where((id) => !next.contains(id)));
    selectedMenuIds.assignAll(next);
    return save();
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await save();
  }

  Future<void> setThemeMode(String mode) async {
    themeMode.value = _sanitizeThemeMode(mode);
    await save();
  }

  String _sanitizeThemeMode(String? raw) {
    switch (raw) {
      case 'light':
      case 'dark':
        return raw!;
      default:
        return 'system';
    }
  }

  Map<String, dynamic> _configPayload(String tenantId, String t) => {
        'tenant_id': tenantId,
        'token': t,
        'menu_ids': selectedMenuIds.toList(),
        'enabled': enabled.value,
        'theme_mode': themeMode.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  Future<bool> save() async {
    final tenantId = _tenantId;
    if (tenantId == null) return false;
    saving.value = true;
    try {
      var t = token.value.trim();
      if (t.isEmpty) t = await _ensureRow(tenantId);
      await _withLocalWrite(() async {
        await _db.from('digital_menu_config').upsert(_configPayload(tenantId, t));
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

  /// Rotates the public token (invalidates old QR links) on every device.
  Future<bool> regenerateToken() async {
    final tenantId = _tenantId;
    if (tenantId == null) return false;
    final newToken = _randomToken();
    saving.value = true;
    try {
      await _withLocalWrite(() async {
        await _db
            .from('digital_menu_config')
            .upsert(_configPayload(tenantId, newToken));
      });
      token.value = newToken;
      _showSyncNotice('Yeni bağlantı oluşturuldu');
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
