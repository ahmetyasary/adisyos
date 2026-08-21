import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/models/payment_type.dart';
import 'package:orderix/models/receipt_layout.dart';

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
  /// Whether the Ordi FAB is shown on every device for this account.
  final RxBool ordiVisible = true.obs;
  /// Ordi FAB size: `sm` | `md` | `lg`.
  final RxString ordiSize = 'md'.obs;
  /// App-wide haptic / vibration feedback.
  final RxBool hapticsEnabled = true.obs;
  /// App-wide UI sounds paired with haptic moments.
  final RxBool soundsEnabled = true.obs;
  /// Account UI language: `tr` | `en`.
  final RxString language = 'tr'.obs;
  /// Account payment methods (nakit/kart/havale + custom, e.g. yemek kartı).
  final RxList<PaymentType> paymentTypes =
      List<PaymentType>.from(kDefaultPaymentTypes).obs;
  /// Thermal receipt (adisyon) print layout for this account.
  final Rx<ReceiptLayout> receiptLayout = ReceiptLayout.defaults.obs;
  /// Last chosen discount UI mode: `percent` | `amount` (synced across devices).
  final RxString discountMode = 'percent'.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  /// Ignore realtime echoes of our own Ordi-corner writes for a short window.
  DateTime? _localOrdiCornerWriteAt;

  String? _currentTenantId() => _db.auth.currentUser?.id;

  String _tenantPrefKey(String tenantId, String key) =>
      'settings.$tenantId.$key';

  static const _kCompanyName    = 'company_name';
  static const _kCurrencySymbol = 'currency_symbol';
  static const _kNavOrder       = 'nav_order';
  static const _kOrdiCorner     = 'ordi_corner';
  static const _kOrdiVisible    = 'ordi_visible';
  static const _kOrdiSize       = 'ordi_size';
  static const _kHapticsEnabled = 'haptics_enabled';
  static const _kSoundsEnabled  = 'sounds_enabled';
  static const _kLanguage       = 'language';
  static const _kPaymentTypes   = 'payment_types';
  static const _kReceiptLayout  = 'receipt_layout';
  static const _kDiscountMode   = 'discount_mode';

  /// Pixel diameter of the Ordi badge for the current [ordiSize].
  double get ordiFabSize {
    switch (ordiSize.value) {
      case 'sm':
        return 46;
      case 'lg':
        return 70;
      default:
        return 58;
    }
  }

  /// Touch target around the Ordi badge.
  double get ordiHitSize => ordiFabSize + 24;

  /// Display name for a stored payment method id (falls back to the id).
  String paymentMethodLabel(String id) {
    for (final t in paymentTypes) {
      if (t.id == id) return t.name;
    }
    switch (id) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kredi Kartı';
      case 'transfer':
        return 'Havale';
      default:
        return id;
    }
  }

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
        ordiVisible.value = true;
        ordiSize.value = 'md';
        hapticsEnabled.value = true;
        soundsEnabled.value = true;
        language.value = 'tr';
        _applyLocale('tr');
        paymentTypes.assignAll(kDefaultPaymentTypes);
        receiptLayout.value = ReceiptLayout.defaults;
        discountMode.value = 'percent';
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
    final tenantId = _currentTenantId();
    final channelName = tenantId == null
        ? 'settings_changes'
        : 'settings_changes_$tenantId';

    var channel = _db.channel(channelName);
    if (tenantId != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_settings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: tenantId,
        ),
        callback: _onSettingsChange,
      );
    } else {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_settings',
        callback: _onSettingsChange,
      );
    }
    _channel = channel.subscribe();
  }

  void _onSettingsChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
    if (row.isNotEmpty) {
      _applySettingsRow(Map<String, dynamic>.from(row));
    }
    // Full reload keeps prefs + other keys consistent.
    _load();
  }

  /// Hot-path apply so Ordi corner (and similar) move without waiting on select.
  void _applySettingsRow(Map<String, dynamic> row) {
    final key = row['key'] as String?;
    final rawVal = (row['value'] as String?) ?? '';
    if (key == null || rawVal.isEmpty) return;

    switch (key) {
      case _kOrdiCorner:
        final localAt = _localOrdiCornerWriteAt;
        if (localAt != null &&
            DateTime.now().difference(localAt) <
                const Duration(milliseconds: 900)) {
          return;
        }
        final next = _sanitizeCorner(rawVal);
        if (ordiCorner.value != next) {
          ordiCorner.value = next;
          _writePref(_kOrdiCorner, next);
        }
      case _kOrdiVisible:
        final next = rawVal != '0' && rawVal != 'false';
        if (ordiVisible.value != next) ordiVisible.value = next;
      case _kOrdiSize:
        final next = _sanitizeOrdiSize(rawVal);
        if (ordiSize.value != next) ordiSize.value = next;
      case _kLanguage:
        final next = _sanitizeLanguage(rawVal);
        if (language.value != next) {
          language.value = next;
          _applyLocale(next);
          _writePref(_kLanguage, next);
        }
      case _kDiscountMode:
        final next = _sanitizeDiscountMode(rawVal);
        if (discountMode.value != next) {
          discountMode.value = next;
          _writePref(_kDiscountMode, next);
        }
      default:
        break;
    }
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
    _localOrdiCornerWriteAt = DateTime.now();
    await _writePref(_kOrdiCorner, next);
    try {
      await _writeValue(_kOrdiCorner, next);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setOrdiCorner DB error: $e');
    }
  }

  Future<void> setOrdiVisible(bool visible) async {
    ordiVisible.value = visible;
    final value = visible ? '1' : '0';
    await _writePref(_kOrdiVisible, value);
    try {
      await _writeValue(_kOrdiVisible, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setOrdiVisible DB error: $e');
    }
  }

  Future<void> setOrdiSize(String size) async {
    final next = _sanitizeOrdiSize(size);
    ordiSize.value = next;
    await _writePref(_kOrdiSize, next);
    try {
      await _writeValue(_kOrdiSize, next);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setOrdiSize DB error: $e');
    }
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabled.value = enabled;
    final value = enabled ? '1' : '0';
    await _writePref(_kHapticsEnabled, value);
    try {
      await _writeValue(_kHapticsEnabled, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setHapticsEnabled DB error: $e');
    }
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    soundsEnabled.value = enabled;
    final value = enabled ? '1' : '0';
    await _writePref(_kSoundsEnabled, value);
    try {
      await _writeValue(_kSoundsEnabled, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setSoundsEnabled DB error: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    final next = _sanitizeLanguage(code);
    language.value = next;
    _applyLocale(next);
    await _writePref(_kLanguage, next);
    // Mirror legacy flat key used by older builds.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', next);
    } catch (_) {}
    try {
      await _writeValue(_kLanguage, next);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setLanguage DB error: $e');
    }
  }

  void _applyLocale(String code) {
    final locale =
        code == 'en' ? const Locale('en', 'US') : const Locale('tr', 'TR');
    if (Get.locale?.languageCode != locale.languageCode) {
      Get.updateLocale(locale);
    }
  }

  String _sanitizeLanguage(String raw) {
    switch (raw) {
      case 'en':
        return 'en';
      default:
        return 'tr';
    }
  }

  Future<void> setReceiptLayout(ReceiptLayout layout) async {
    receiptLayout.value = layout;
    final value = encodeReceiptLayoutJson(layout);
    await _writePref(_kReceiptLayout, value);
    try {
      await _writeValue(_kReceiptLayout, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setReceiptLayout DB error: $e');
    }
  }

  Future<void> updateReceiptLayout(ReceiptLayout Function(ReceiptLayout) fn) =>
      setReceiptLayout(fn(receiptLayout.value));

  Future<void> setDiscountMode(String mode) async {
    final next = _sanitizeDiscountMode(mode);
    if (discountMode.value == next) return;
    discountMode.value = next;
    await _writePref(_kDiscountMode, next);
    try {
      await _writeValue(_kDiscountMode, next);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] setDiscountMode DB error: $e');
    }
  }

  bool get isDiscountPercent => discountMode.value != 'amount';

  String _sanitizeDiscountMode(String raw) {
    switch (raw) {
      case 'amount':
        return 'amount';
      default:
        return 'percent';
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

  String _sanitizeOrdiSize(String raw) {
    switch (raw) {
      case 'sm':
      case 'md':
      case 'lg':
        return raw;
      default:
        return 'md';
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

  Future<void> _persistPaymentTypes(List<PaymentType> types) async {
    paymentTypes.assignAll(types);
    final value = encodePaymentTypesJson(types);
    await _writePref(_kPaymentTypes, value);
    try {
      await _writeValue(_kPaymentTypes, value);
    } catch (e) {
      if (kDebugMode) print('[SettingsService] paymentTypes DB error: $e');
    }
  }

  /// Adds a custom payment type (e.g. Multinet, Sodexo). Returns false if empty
  /// or duplicate name.
  Future<bool> addPaymentType(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (paymentTypes.any((t) => t.name.toLowerCase() == lower)) return false;
    final id = _newPaymentTypeId(trimmed);
    final next = [...paymentTypes, PaymentType(id: id, name: trimmed)];
    await _persistPaymentTypes(next);
    return true;
  }

  Future<bool> renamePaymentType(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (paymentTypes
        .any((t) => t.id != id && t.name.toLowerCase() == lower)) {
      return false;
    }
    final next = paymentTypes
        .map((t) => t.id == id ? t.copyWith(name: trimmed) : t)
        .toList();
    await _persistPaymentTypes(next);
    return true;
  }

  /// Removes a custom type. Built-ins cannot be deleted.
  Future<bool> removePaymentType(String id) async {
    PaymentType? target;
    for (final t in paymentTypes) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    if (target == null || target.builtin) return false;
    await _persistPaymentTypes(
      paymentTypes.where((t) => t.id != id).toList(),
    );
    return true;
  }

  String _newPaymentTypeId(String name) {
    const chars = 'abcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    final suffix =
        List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
    final ascii = name
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = ascii.isEmpty
        ? 'odeme'
        : ascii.substring(0, min(ascii.length, 20));
    var id = '${base}_$suffix';
    final existing = paymentTypes.map((t) => t.id).toSet();
    var n = 0;
    while (existing.contains(id)) {
      n++;
      id = '${base}_${suffix}_$n';
    }
    return id;
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
      String? readOrdiVisible;
      String? readOrdiSize;
      String? readHaptics;
      String? readSounds;
      String? readLanguage;
      String? readPayTypes;
      String? readReceipt;
      String? readDiscountMode;

      if (tenantId != null) {
        readName   = prefs.getString(_tenantPrefKey(tenantId, _kCompanyName));
        readSymbol = prefs.getString(_tenantPrefKey(tenantId, _kCurrencySymbol));
        readNav    = prefs.getString(_tenantPrefKey(tenantId, _kNavOrder));
        readCorner = prefs.getString(_tenantPrefKey(tenantId, _kOrdiCorner));
        readOrdiVisible =
            prefs.getString(_tenantPrefKey(tenantId, _kOrdiVisible));
        readOrdiSize =
            prefs.getString(_tenantPrefKey(tenantId, _kOrdiSize));
        readHaptics =
            prefs.getString(_tenantPrefKey(tenantId, _kHapticsEnabled));
        readSounds =
            prefs.getString(_tenantPrefKey(tenantId, _kSoundsEnabled));
        readLanguage =
            prefs.getString(_tenantPrefKey(tenantId, _kLanguage));
        readPayTypes =
            prefs.getString(_tenantPrefKey(tenantId, _kPaymentTypes));
        readReceipt =
            prefs.getString(_tenantPrefKey(tenantId, _kReceiptLayout));
        readDiscountMode =
            prefs.getString(_tenantPrefKey(tenantId, _kDiscountMode));
      }

      // Legacy fallback — pre-tenant-scoping installs stored flat keys.
      readName   ??= prefs.getString('settings.$_kCompanyName');
      readSymbol ??= prefs.getString('settings.$_kCurrencySymbol');
      readNav    ??= prefs.getString('settings.$_kNavOrder');
      readCorner ??= prefs.getString('settings.$_kOrdiCorner');
      readOrdiVisible ??= prefs.getString('settings.$_kOrdiVisible');
      readOrdiSize ??= prefs.getString('settings.$_kOrdiSize');
      readHaptics ??= prefs.getString('settings.$_kHapticsEnabled');
      readSounds ??= prefs.getString('settings.$_kSoundsEnabled');
      readLanguage ??= prefs.getString('settings.$_kLanguage');
      // Older builds stored language outside the settings.* namespace.
      readLanguage ??= prefs.getString('language');
      readPayTypes ??= prefs.getString('settings.$_kPaymentTypes');
      readReceipt ??= prefs.getString('settings.$_kReceiptLayout');
      readDiscountMode ??= prefs.getString('settings.$_kDiscountMode');

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
      if (readOrdiVisible != null && readOrdiVisible.isNotEmpty) {
        ordiVisible.value = readOrdiVisible != '0' && readOrdiVisible != 'false';
      }
      if (readOrdiSize != null && readOrdiSize.isNotEmpty) {
        ordiSize.value = _sanitizeOrdiSize(readOrdiSize);
      }
      if (readHaptics != null && readHaptics.isNotEmpty) {
        hapticsEnabled.value =
            readHaptics != '0' && readHaptics != 'false';
      }
      if (readSounds != null && readSounds.isNotEmpty) {
        soundsEnabled.value = readSounds != '0' && readSounds != 'false';
      }
      if (readLanguage != null && readLanguage.isNotEmpty) {
        language.value = _sanitizeLanguage(readLanguage);
        _applyLocale(language.value);
      }
      if (readPayTypes != null && readPayTypes.isNotEmpty) {
        paymentTypes.assignAll(parsePaymentTypesJson(readPayTypes));
      }
      if (readReceipt != null && readReceipt.isNotEmpty) {
        receiptLayout.value = parseReceiptLayoutJson(readReceipt);
      }
      if (readDiscountMode != null && readDiscountMode.isNotEmpty) {
        discountMode.value = _sanitizeDiscountMode(readDiscountMode);
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
          case _kOrdiVisible:
            if (rawVal.isNotEmpty) {
              ordiVisible.value = rawVal != '0' && rawVal != 'false';
              await _writePref(_kOrdiVisible, ordiVisible.value ? '1' : '0');
            }
          case _kOrdiSize:
            if (rawVal.isNotEmpty) {
              ordiSize.value = _sanitizeOrdiSize(rawVal);
              await _writePref(_kOrdiSize, ordiSize.value);
            }
          case _kHapticsEnabled:
            if (rawVal.isNotEmpty) {
              hapticsEnabled.value = rawVal != '0' && rawVal != 'false';
              await _writePref(
                  _kHapticsEnabled, hapticsEnabled.value ? '1' : '0');
            }
          case _kSoundsEnabled:
            if (rawVal.isNotEmpty) {
              soundsEnabled.value = rawVal != '0' && rawVal != 'false';
              await _writePref(
                  _kSoundsEnabled, soundsEnabled.value ? '1' : '0');
            }
          case _kLanguage:
            if (rawVal.isNotEmpty) {
              final next = _sanitizeLanguage(rawVal);
              if (language.value != next) {
                language.value = next;
                _applyLocale(next);
              }
              await _writePref(_kLanguage, next);
            }
          case _kPaymentTypes:
            if (rawVal.isNotEmpty) {
              paymentTypes.assignAll(parsePaymentTypesJson(rawVal));
              await _writePref(_kPaymentTypes, rawVal);
            }
          case _kReceiptLayout:
            if (rawVal.isNotEmpty) {
              receiptLayout.value = parseReceiptLayoutJson(rawVal);
              await _writePref(_kReceiptLayout, rawVal);
            }
          case _kDiscountMode:
            if (rawVal.isNotEmpty) {
              discountMode.value = _sanitizeDiscountMode(rawVal);
              await _writePref(_kDiscountMode, discountMode.value);
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
