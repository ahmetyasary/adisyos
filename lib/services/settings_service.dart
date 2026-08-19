import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tenant-aware, local-first settings store.
///
/// Design goals:
/// * The UI always has a value to render — the local cache is authoritative
///   until the DB confirms something newer. A failed/blocked Supabase write
///   never wipes the user's locally saved value.
/// * Writes are tolerant of a missing `(tenant_id, key)` unique constraint:
///   if `upsert(onConflict: ...)` fails we fall back to an explicit
///   select → update/insert path so the save still goes through.
/// * Errors from the DB surface to callers so the UI can show the real cause.
class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  /// Shortcut for reading the current currency symbol inside an `Obx`.
  static String get cs => SettingsService.to.currencySymbol.value;

  // Max length we accept for company name. Keeps prefs/DB storage bounded
  // and matches a reasonable UI footer layout.
  static const int _companyNameMaxLength = 80;

  // Reactive state bound to the UI.
  final RxString companyName    = ''.obs;
  final RxString currencySymbol = '₺'.obs;
  /// Ordered ids of main sidebar sections. Empty → built-in default order.
  final RxList<String> navOrder = <String>[].obs;
  /// Shared Ordi FAB corner for this account: `tl` | `tr` | `bl` | `br`.
  final RxString ordiCorner = 'br'.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String? _currentTenantId() => _db.auth.currentUser?.id;

  String _tenantPrefKey(String tenantId, String key) =>
      'settings.$tenantId.$key';

  static const _kCompanyName    = 'company_name';
  static const _kCurrencySymbol = 'currency_symbol';
  static const _kNavOrder       = 'nav_order';
  static const _kOrdiCorner     = 'ordi_corner';

  @override
  void onInit() {
    super.onInit();

    // Hydrate from the local cache immediately so the UI never flickers the
    // hardcoded fallback on cold start.
    _loadFromPrefs();

    _db.auth.onAuthStateChange.listen((data) {
      final ev = data.event;
      // `initialSession` fires on cold start when a stored session is restored.
      // `signedIn` fires on a fresh login. Both mean `auth.currentUser` is ready.
      if ((ev == AuthChangeEvent.signedIn ||
              ev == AuthChangeEvent.initialSession) &&
          data.session != null) {
        _loadFromPrefs();
        _load();
        _resubscribeRealtime();
      }
      if (ev == AuthChangeEvent.signedOut) {
        // Reset in-memory state so the next account doesn't leak the previous
        // company name. The per-tenant prefs cache is kept so re-login
        // rehydrates instantly.
        companyName.value = '';
        currencySymbol.value = '₺';
        navOrder.clear();
        ordiCorner.value = 'br';
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

  // ── Public API ─────────────────────────────────────────────────

  /// Re-reads from the remote DB. Local cache is preserved if the DB is
  /// empty or contains only blank values (see [_load]).
  Future<void> refresh() => _load();

  /// Persists a new company name. Optimistically updates the in-memory
  /// value + local cache, then writes to Supabase. Throws [PostgrestException]
  /// (or a generic [Exception]) if the DB write fails so the UI can display
  /// the real error.
  Future<void> save({String? newCompanyName}) async {
    if (newCompanyName == null) return;

    var trimmed = newCompanyName.trim();
    if (trimmed.length > _companyNameMaxLength) {
      trimmed = trimmed.substring(0, _companyNameMaxLength);
    }

    companyName.value = trimmed;
    await _writePref(_kCompanyName, trimmed);

    await _writeValue(_kCompanyName, trimmed);
  }

  /// Persists the admin-chosen sidebar order for this tenant.
  Future<void> setNavOrder(List<String> ids) async {
    navOrder.assignAll(ids);
    final value = ids.join(',');
    await _writePref(_kNavOrder, value);
    try {
      await _writeValue(_kNavOrder, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setNavOrder DB error: $e');
    }
  }

  Future<void> resetNavOrder() => setNavOrder(const []);

  /// Persists the account-wide Ordi corner. Local + prefs first, then Supabase
  /// so iPhone and iPad stay in sync.
  Future<void> setOrdiCorner(String corner) async {
    final next = _sanitizeCorner(corner);
    ordiCorner.value = next;
    await _writePref(_kOrdiCorner, next);
    try {
      await _writeValue(_kOrdiCorner, next);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setOrdiCorner DB error: $e');
    }
  }

  String _sanitizeCorner(String raw) {
    switch (raw) {
      case 'tl':
      case 'tr':
      case 'bl':
      case 'br':
        return raw;
      default:
        return 'br';
    }
  }

  /// Persists a new currency symbol. Same guarantees as [save].
  Future<void> setCurrency(String symbol) async {
    currencySymbol.value = symbol;
    await _writePref(_kCurrencySymbol, symbol);
    try {
      await _writeValue(_kCurrencySymbol, symbol);
    } catch (e) {
      // Currency is a tap-to-change control — we don't want to throw from a
      // row tap. Log and keep the optimistic local value.
      if (kDebugMode) print('[SettingsService] setCurrency DB error: $e');
    }
  }

  // ── Internals ──────────────────────────────────────────────────

  /// Hydrate reactive values from SharedPreferences (tenant-scoped when we
  /// know the tenant; falls back to the legacy un-scoped keys so existing
  /// installs keep their value after upgrading).
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = _currentTenantId();

      String? readName;
      String? readSymbol;
      String? readNav;
      String? readCorner;

      if (tenantId != null) {
        readName   = prefs.getString(_tenantPrefKey(tenantId, _kCompanyName));
        readSymbol = prefs.getString(_tenantPrefKey(tenantId, _kCurrencySymbol));
        readNav    = prefs.getString(_tenantPrefKey(tenantId, _kNavOrder));
        readCorner = prefs.getString(_tenantPrefKey(tenantId, _kOrdiCorner));
      }

      // Legacy fallback — pre-tenant-scoping installs stored flat keys.
      readName   ??= prefs.getString('settings.$_kCompanyName');
      readSymbol ??= prefs.getString('settings.$_kCurrencySymbol');
      readNav    ??= prefs.getString('settings.$_kNavOrder');
      readCorner ??= prefs.getString('settings.$_kOrdiCorner');

      if (readName != null && readName.isNotEmpty) {
        companyName.value = readName;
      }
      if (readSymbol != null && readSymbol.isNotEmpty) {
        currencySymbol.value = readSymbol;
      }
      if (readNav != null) {
        navOrder.assignAll(_parseNavOrder(readNav));
      }
      if (readCorner != null && readCorner.isNotEmpty) {
        ordiCorner.value = _sanitizeCorner(readCorner);
      }
    } catch (e) {
      if (kDebugMode) print('[SettingsService] prefs load error: $e');
    }
  }

  List<String> _parseNavOrder(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _writePref(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = _currentTenantId();
      if (tenantId != null) {
        await prefs.setString(_tenantPrefKey(tenantId, key), value);
      }
      // Mirror to the legacy flat key so anything still reading it (or
      // downgrades) keeps working.
      await prefs.setString('settings.$key', value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] prefs write error ($key): $e');
    }
  }

  /// Reads the server-side state. Only overwrites the local cache when the
  /// remote row exists AND has a non-empty value — so a missing row or an
  /// empty/legacy row never clobbers a value the user just saved locally.
  Future<void> _load() async {
    final tenantId = _currentTenantId();
    if (tenantId == null) return;
    try {
      final rows = await _db
          .from('app_settings')
          .select()
          .eq('tenant_id', tenantId);

      String? ordiFromShared;
      String? ordiFromLegacyDevice;

      for (final row in rows) {
        final rawKey = row['key'] as String?;
        final rawVal = (row['value'] as String?) ?? '';
        if (rawKey == null) continue;

        switch (rawKey) {
          case _kCompanyName:
            if (rawVal.isNotEmpty) {
              companyName.value = rawVal;
              await _writePref(_kCompanyName, rawVal);
            }
          case _kCurrencySymbol:
            if (rawVal.isNotEmpty) {
              currencySymbol.value = rawVal;
              await _writePref(_kCurrencySymbol, rawVal);
            }
          case _kNavOrder:
            navOrder.assignAll(_parseNavOrder(rawVal));
            await _writePref(_kNavOrder, rawVal);
          case _kOrdiCorner:
            if (rawVal.isNotEmpty) {
              ordiFromShared = rawVal;
            }
          default:
            if (rawKey.startsWith('ordi_corner.') && rawVal.isNotEmpty) {
              ordiFromLegacyDevice ??= rawVal;
            }
        }
      }

      final ordiVal = ordiFromShared ?? ordiFromLegacyDevice;
      if (ordiVal != null && ordiVal.isNotEmpty) {
        ordiCorner.value = _sanitizeCorner(ordiVal);
        await _writePref(_kOrdiCorner, ordiCorner.value);
      }
    } catch (e) {
      if (kDebugMode) print('[SettingsService] load error: $e');
    }
  }

  /// Writes a single setting. Tries the fast upsert path first (requires the
  /// `(tenant_id, key)` unique index from the migration) and falls back to an
  /// explicit select → update / insert if the upsert fails for any reason
  /// (missing index, schema mismatch, older Postgres, etc).
  ///
  /// Re-throws the final error so `save()` callers can surface it.
  Future<void> _writeValue(String key, String value) async {
    final tenantId = _currentTenantId();
    if (tenantId == null) {
      throw StateError('Cannot save settings: not authenticated');
    }

    final row = {
      'key': key,
      'value': value,
      'tenant_id': tenantId,
    };

    try {
      await _db
          .from('app_settings')
          .upsert(row, onConflict: 'tenant_id,key');
      return;
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsService] upsert failed for $key, falling back: $e');
      }
      // Fall through to manual path.
    }

    // Manual upsert fallback — does not depend on a unique constraint
    // OR on the table having an `id` column. Works on any shape where
    // (tenant_id, key) logically identifies a row.
    try {
      final existing = await _db
          .from('app_settings')
          .select('key')
          .eq('tenant_id', tenantId)
          .eq('key', key)
          .maybeSingle();

      if (existing != null) {
        await _db
            .from('app_settings')
            .update({'value': value})
            .eq('tenant_id', tenantId)
            .eq('key', key);
      } else {
        await _db.from('app_settings').insert(row);
      }
    } catch (e) {
      if (kDebugMode) print('[SettingsService] fallback write error ($key): $e');
      rethrow;
    }
  }
}
