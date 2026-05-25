import 'dart:io';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Set these via --dart-define at build/run time:
//   --dart-define=REVENUECAT_APPLE_KEY=appl_xxxx
//   --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxxx
const String _kAppleKey  = String.fromEnvironment('REVENUECAT_APPLE_KEY');
const String _kGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

// Must match the entitlement identifier in your RevenueCat dashboard.
const String kEntitlementId = 'premium';

const int kTrialDays = 14;

class SubscriptionService extends GetxService {
  static SubscriptionService get to => Get.find();

  final Rx<CustomerInfo?> customerInfo = Rx(null);
  final RxBool isPurchasing = false.obs;

  static bool _sdkReady = false;

  // ── SDK init (call before runApp) ─────────────────────────────

  static Future<void> configure() async {
    final key = Platform.isIOS ? _kAppleKey : _kGoogleKey;
    if (key.trim().isEmpty) return;
    try {
      await Purchases.setLogLevel(LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(key));
      _sdkReady = true;
    } catch (_) {}
  }

  // ── Access gate ───────────────────────────────────────────────

  /// True when the user may use the app (trial active OR subscription active).
  ///
  /// Trial is derived purely from Supabase `created_at`, so it works even if
  /// the RevenueCat SDK never initialises. Once the trial window is over the
  /// user MUST have an active entitlement — we never fall back to allowing
  /// access just because RC hasn't synced yet (that was the previous bug
  /// that silently unlocked expired trials).
  bool get hasAccess {
    if (isInTrial) return true;
    return isSubscribed;
  }

  bool get isSubscribed =>
      customerInfo.value?.entitlements.active.containsKey(kEntitlementId) ??
      false;

  /// True when the account is within the 7-day free trial window.
  bool get isInTrial {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final createdAt = DateTime.tryParse(user.createdAt);
    if (createdAt == null) return false;
    return DateTime.now()
        .isBefore(createdAt.add(const Duration(days: kTrialDays)));
  }

  /// Whole days remaining in the trial (0 when trial has ended).
  int get trialDaysLeft {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 0;
    final createdAt = DateTime.tryParse(user.createdAt);
    if (createdAt == null) return 0;
    final remaining = createdAt
        .add(const Duration(days: kTrialDays))
        .difference(DateTime.now())
        .inDays;
    return remaining.clamp(0, kTrialDays);
  }

  // ── Customer lifecycle ────────────────────────────────────────

  Future<void> loginCustomer(String userId) async {
    if (!_sdkReady) return;
    try {
      final result = await Purchases.logIn(userId);
      customerInfo.value = result.customerInfo;
    } catch (_) {}
  }

  Future<void> logoutCustomer() async {
    if (!_sdkReady) return;
    try {
      customerInfo.value = await Purchases.logOut();
    } catch (_) {
      customerInfo.value = null;
    }
  }

  Future<void> refreshCustomerInfo() async {
    if (!_sdkReady) return;
    try {
      customerInfo.value = await Purchases.getCustomerInfo();
    } catch (_) {}
  }

  // ── Purchases ─────────────────────────────────────────────────

  Future<Offerings?> getOfferings() async {
    if (!_sdkReady) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the purchase grants the premium entitlement.
  /// Throws [PurchasesError] on non-cancellation failures.
  Future<bool> purchasePackage(Package package) async {
    isPurchasing.value = true;
    try {
      final info = await Purchases.purchasePackage(package);
      customerInfo.value = info;
      return info.entitlements.active.containsKey(kEntitlementId);
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) return false;
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
