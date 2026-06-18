import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Set these via --dart-define at build/run time:
//   --dart-define=REVENUECAT_APPLE_KEY=appl_xxxx
//   --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxxx
const String _kAppleKey  = String.fromEnvironment('REVENUECAT_APPLE_KEY');
const String _kGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

// Must match the entitlement identifier in your RevenueCat dashboard.
const String kEntitlementId = 'Orderix Pro';

// The free-trial length is defined by the StoreKit introductory offer
// configured on the products in App Store Connect / Google Play — NOT here.
// This constant is only used for display fallbacks.
const int kTrialDays = 14;

class SubscriptionService extends GetxService {
  static SubscriptionService get to => Get.find();

  final Rx<CustomerInfo?> customerInfo = Rx(null);
  final RxBool isPurchasing = false.obs;

  static bool _sdkReady = false;

  // Tracks whether we've reconciled the current session against the Apple
  // receipt yet. The free trial / subscription belongs to the Apple ID
  // (the StoreKit receipt), not to the Supabase user we logged in with, so
  // before we ever lock a user out we recover any entitlement the Apple ID
  // already owns. See [syncFromReceipt] / [receiptSyncSettled].
  bool _receiptSyncDone = false;
  bool _receiptSyncing = false;

  // ── SDK init (call before runApp) ─────────────────────────────

  static Future<void> configure() async {
    final key = Platform.isIOS ? _kAppleKey : _kGoogleKey;
    debugPrint('[RC] configure() platform=${Platform.operatingSystem} '
        'keyPresent=${key.trim().isNotEmpty} '
        'keyPrefix=${key.isEmpty ? "<empty>" : key.substring(0, key.length.clamp(0, 5))}');
    if (key.trim().isEmpty) {
      debugPrint('[RC] ⚠️ API key is EMPTY — did you pass '
          '--dart-define=REVENUECAT_APPLE_KEY / _GOOGLE_KEY for this platform?');
      return;
    }
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(key));
      _sdkReady = true;
      debugPrint('[RC] ✅ configured, sdkReady=true');
    } catch (e, st) {
      debugPrint('[RC] ❌ configure failed: $e\n$st');
    }
  }

  // ── Access gate ───────────────────────────────────────────────

  /// The active premium entitlement, or null when the user has none.
  ///
  /// During an Apple-managed introductory free trial RevenueCat reports the
  /// entitlement as active (with `periodType == trial`), so a single
  /// entitlement check covers both the trial and the paid period.
  EntitlementInfo? get _entitlement =>
      customerInfo.value?.entitlements.active[kEntitlementId];

  /// True when the user may use the app: an active entitlement, whether that
  /// is a free trial, an introductory price, or a full paid subscription.
  ///
  /// We never fall back to allowing access just because RC hasn't synced yet —
  /// no entitlement means no access.
  bool get hasAccess => isSubscribed;

  bool get isSubscribed => _entitlement != null;

  /// True while the active entitlement is still in its StoreKit free-trial
  /// (or introductory) period rather than the full-price paid period.
  bool get isInTrial {
    final type = _entitlement?.periodType;
    return type == PeriodType.trial || type == PeriodType.intro;
  }

  /// Whole days remaining before the current period (trial or paid) renews
  /// or expires. Returns 0 only when there is no active/remaining entitlement.
  ///
  /// We round the remaining time *up* so a freshly started 14-day trial reads
  /// "14" (not 13 from truncation) and a still-active period in its final <24h
  /// reads "1" — never "0 gün kaldı" while access is genuinely still valid.
  int get daysLeft {
    final exp = _entitlement?.expirationDate;
    if (exp == null) return 0;
    final end = DateTime.tryParse(exp);
    if (end == null) return 0;
    final remaining = end.difference(DateTime.now());
    if (remaining.inMinutes <= 0) return 0;
    return (remaining.inMinutes / (60 * 24)).ceil().clamp(1, 99999);
  }

  // ── Customer lifecycle ────────────────────────────────────────

  Future<void> loginCustomer(String userId) async {
    // A new session must re-reconcile with the Apple receipt.
    _receiptSyncDone = false;
    if (!_sdkReady) return;
    try {
      final result = await Purchases.logIn(userId);
      customerInfo.value = result.customerInfo;
    } catch (_) {}
  }

  Future<void> logoutCustomer() async {
    _receiptSyncDone = false;
    if (!_sdkReady) return;
    try {
      customerInfo.value = await Purchases.logOut();
    } catch (_) {
      customerInfo.value = null;
    }
  }

  /// Reconciles the signed-in RevenueCat customer with the Apple receipt so
  /// that an entitlement already owned by this Apple ID — e.g. a free trial
  /// started earlier, or a subscription bought under a *different* Supabase
  /// account on the same device — is recovered and attached to the current
  /// user. This is what prevents the paywall from re-appearing on every
  /// login once the Apple ID has started its trial.
  ///
  /// Silent (no spinner, no user-facing restore prompt) and runs at most once
  /// per session. [receiptSyncSettled] reports `true` once an attempt has
  /// completed so the access gate knows it may proceed.
  Future<void> syncFromReceipt() async {
    if (!_sdkReady) {
      _receiptSyncDone = true;
      return;
    }
    if (_receiptSyncing || _receiptSyncDone) return;
    _receiptSyncing = true;
    try {
      customerInfo.value = await Purchases.restorePurchases();
    } catch (_) {
      // A failed reconciliation must not trap the user behind the paywall
      // forever; we mark it settled and fall back to whatever RC already knows.
    } finally {
      _receiptSyncing = false;
      _receiptSyncDone = true;
    }
  }

  /// True once [syncFromReceipt] has finished an attempt for this session.
  /// While `false`, the access gate must not show the lockout paywall yet —
  /// we may still recover an Apple-ID-owned entitlement.
  bool get receiptSyncSettled => _receiptSyncDone;

  Future<void> refreshCustomerInfo() async {
    if (!_sdkReady) return;
    try {
      customerInfo.value = await Purchases.getCustomerInfo();
    } catch (_) {}
  }

  // ── Purchases ─────────────────────────────────────────────────

  Future<Offerings?> getOfferings() async {
    if (!_sdkReady) {
      debugPrint('[RC] getOfferings() skipped — sdkReady=false');
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      final m = current?.monthly?.storeProduct;
      final a = current?.annual?.storeProduct;
      debugPrint('[RC] getOfferings() ok — '
          'all=${offerings.all.keys.toList()} '
          'current=${current?.identifier} '
          'monthly=${m?.identifier} '
          '(${m?.priceString} ${m?.currencyCode}) '
          'annual=${a?.identifier} '
          '(${a?.priceString} ${a?.currencyCode}) '
          'pkgCount=${current?.availablePackages.length ?? 0}');
      return offerings;
    } catch (e, st) {
      debugPrint('[RC] ❌ getOfferings failed: $e\n$st');
      return null;
    }
  }

  /// Returns true when the purchase grants the premium entitlement.
  ///
  /// `Purchases.purchase` throws a [PlatformException]; the RevenueCat error
  /// code is decoded via [PurchasesErrorHelper.getErrorCode]. We swallow the
  /// two non-error outcomes (user cancelled, already subscribed) and only
  /// rethrow genuine failures for the caller to surface.
  Future<bool> purchasePackage(Package package) async {
    isPurchasing.value = true;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      customerInfo.value = result.customerInfo;
      return result.customerInfo.entitlements.active
          .containsKey(kEntitlementId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      // User dismissed the purchase sheet — not an error.
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      // Re-tapped "subscribe" after already owning it: sync the latest
      // entitlement instead of showing an error (this is the iOS
      // "You're currently subscribed to this" case).
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        await refreshCustomerInfo();
        return isSubscribed;
      }
      rethrow;
    } finally {
      isPurchasing.value = false;
    }
  }

  /// Returns true when restored purchases include an active entitlement.
  Future<bool> restorePurchases() async {
    isPurchasing.value = true;
    try {
      final info = await Purchases.restorePurchases();
      customerInfo.value = info;
      return info.entitlements.active.containsKey(kEntitlementId);
    } catch (_) {
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }
}
