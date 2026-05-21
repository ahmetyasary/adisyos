import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/services/subscription_service.dart';
import 'package:orderix/views/auth_screen.dart';
import 'package:orderix/widgets/app_toast.dart';

// ── Design tokens ──────────────────────────────────────────────
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _surface     = Color(0xFFF2F2F7);
const _border      = Color(0xFFE5E5EA);
const _green       = Color(0xFF34C759);

// ──────────────────────────────────────────────────────────────
// Public entry point
// ──────────────────────────────────────────────────────────────

/// Presents the paywall as a native-iOS-style modal bottom sheet.
///
/// Use [dismissible: false] for hard lockout (e.g. trial expired) so the
/// user must purchase or log out. Use [dismissible: true] when the user
/// opens it voluntarily (e.g. the "Abone Ol" button in Settings).
Future<void> showPaywallSheet(
  BuildContext context, {
  bool dismissible = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PaywallSheet(dismissible: dismissible),
  );
}

// ──────────────────────────────────────────────────────────────
// _PaywallSheet
// ──────────────────────────────────────────────────────────────

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({required this.dismissible});
  final bool dismissible;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  Offerings? _offerings;
  bool _loading      = true;
  int  _selectedIdx  = 1; // 0 = monthly, 1 = yearly (pre-selected)

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await SubscriptionService.to.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _loading   = false;
      });
    }
  }

  Package? get _monthly  => _offerings?.current?.monthly;
  Package? get _yearly   => _offerings?.current?.annual;
  Package? get _selected => _selectedIdx == 0 ? _monthly : _yearly;

  String? get _savingsBadge {
    if (_monthly == null || _yearly == null) return null;
    final annualCost  = _monthly!.storeProduct.price * 12;
    final yearlyPrice = _yearly!.storeProduct.price;
    if (annualCost <= 0) return null;
    final pct = ((annualCost - yearlyPrice) / annualCost * 100).round();
    return pct > 0 ? '%$pct İndirim' : null;
  }

  Future<void> _onPurchase() async {
    final pkg = _selected;
    if (pkg == null) return;
    try {
      final ok = await SubscriptionService.to.purchasePackage(pkg);
      if (ok && mounted) {
        Navigator.of(context).pop();
        AppToast.success('Abonelik başarıyla başlatıldı');
      }
    } on PurchasesError catch (e) {
      if (e.code != PurchasesErrorCode.purchaseCancelledError) {
        AppToast.error(e.message);
      }
    } catch (_) {
      AppToast.error('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _onRestore() async {
    final ok = await SubscriptionService.to.restorePurchases();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppToast.success('Abonelik başarıyla geri yüklendi');
    } else {
      AppToast.error('Aktif abonelik bulunamadı');
    }
  }

  Future<void> _onLogout() async {
    await AuthController.to.logout();
    Get.offAll(() => const AuthScreen());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.dismissible,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Handle(),
                const SizedBox(height: 20),

                // App icon + brand
                const _BrandHero(),
                const SizedBox(height: 22),

                // Trial expired banner (lockout only)
                if (!widget.dismissible) ...[
                  const _TrialExpiredBanner(),
                  const SizedBox(height: 18),
                ],

                // Feature list
                const _FeatureList(),
                const SizedBox(height: 22),

                // Plan selector
                if (_loading)
                  const _PlanLoading()
                else
                  _PlanRow(
                    monthly:       _monthly,
                    yearly:        _yearly,
                    savingsBadge:  _savingsBadge,
                    selectedIndex: _selectedIdx,
                    onSelect:      (i) => setState(() => _selectedIdx = i),
                  ),
                const SizedBox(height: 18),

                // CTA
                _CtaButton(
                  package:    _selected,
                  onPurchase: _onPurchase,
                ),
                const SizedBox(height: 14),

                // Restore + legal
                _Footer(onRestore: _onRestore),

                // Logout (lockout only)
                if (!widget.dismissible) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _onLogout,
                    style: TextButton.styleFrom(foregroundColor: _textSec),
                    child: const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _Handle — iOS-style drag indicator
// ──────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  36,
      height: 5,
      decoration: BoxDecoration(
        color:        const Color(0xFFD1D1D6),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _BrandHero — app icon + Pro title + subtitle
// ──────────────────────────────────────────────────────────────

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width:  68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      _orange.withValues(alpha: 0.30),
                blurRadius: 24,
                offset:     const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize:      26,
              fontWeight:    FontWeight.w800,
              color:         _textPrimary,
              letterSpacing: -0.6,
              height:        1.1,
            ),
            children: [
              TextSpan(text: 'Orderix '),
              TextSpan(
                text: 'Pro',
                style: TextStyle(color: _orange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Restoranınızı tek bir yerden yönetin',
          style: TextStyle(
            fontSize: 14,
            color:    _textSec,
            height:   1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _TrialExpiredBanner
// ──────────────────────────────────────────────────────────────

class _TrialExpiredBanner extends StatelessWidget {
  const _TrialExpiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFFFF3B30).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF3B30).withValues(alpha: 0.20),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_off_outlined,
              size: 16, color: Color(0xFFFF3B30)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '7 günlük deneme süreniz sona erdi.',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      Color(0xFFFF3B30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _FeatureList — clean iOS-style checkmark list
// ──────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _items = [
    'Sınırsız masa ve sipariş yönetimi',
    'Detaylı satış ve gelir raporları',
    'Mutfak ekranı ve envanter takibi',
    'Personel ve vardiya yönetimi',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _items
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width:  22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: _green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        color:      _textPrimary,
                        height:     1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _PlanLoading
// ──────────────────────────────────────────────────────────────

class _PlanLoading extends StatelessWidget {
  const _PlanLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 110,
      child: Center(
        child: CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _PlanRow — side-by-side monthly / yearly cards
// ──────────────────────────────────────────────────────────────

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.monthly,
    required this.yearly,
    required this.savingsBadge,
    required this.selectedIndex,
    required this.onSelect,
  });

  final Package? monthly;
  final Package? yearly;
  final String?  savingsBadge;
  final int      selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    if (monthly == null && yearly == null) {
      return Container(
        width:  double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        _surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Planlar yüklenemedi.\nİnternet bağlantınızı kontrol edin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _textSec, height: 1.5),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (monthly != null)
            Expanded(
              child: _PlanCard(
                label:    'Aylık',
                price:    monthly!.storeProduct.priceString,
                period:   'her ay',
                selected: selectedIndex == 0,
                badge:    null,
                onTap:    () => onSelect(0),
              ),
            ),
          if (monthly != null && yearly != null)
            const SizedBox(width: 10),
          if (yearly != null)
            Expanded(
              child: _PlanCard(
                label:    'Yıllık',
                price:    yearly!.storeProduct.priceString,
                period:   'her yıl',
                selected: selectedIndex == 1,
                badge:    savingsBadge,
                onTap:    () => onSelect(1),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _PlanCard
// ──────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final String  label;
  final String  price;
  final String  period;
  final bool    selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve:    Curves.easeOut,
        padding:  const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color:        selected ? Colors.white : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _orange : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: label + radio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      selected ? _orange : _textSec,
                  ),
                ),
                Container(
                  width:  18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _orange : Colors.transparent,
                    border: Border.all(
                      color: selected ? _orange : _border,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price
            Text(
              price,
              style: const TextStyle(
                fontSize:      20,
                fontWeight:    FontWeight.w800,
                color:         _textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),

            // Period
            Text(
              period,
              style: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w500,
                color:      _textSec,
              ),
            ),

            // Savings badge
            if (badge != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize:      10,
                    fontWeight:    FontWeight.w800,
                    color:         _orange,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _CtaButton
// ──────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.package, required this.onPurchase});

  final Package?     package;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = SubscriptionService.to.isPurchasing.value;
      final enabled = package != null && !loading;

      return GestureDetector(
        onTap: enabled ? onPurchase : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: BoxDecoration(
            color:        enabled ? _orange : const Color(0xFFD1D1D6),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color:      _orange.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width:  22,
                    height: 22,
                    child:  CircularProgressIndicator(
                      color:       Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Aboneliği Başlat',
                    style: TextStyle(
                      fontSize:      15,
                      fontWeight:    FontWeight.w700,
                      color:         Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}

// ──────────────────────────────────────────────────────────────
// _Footer
// ──────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = SubscriptionService.to.isPurchasing.value;
      return Column(
        children: [
          GestureDetector(
            onTap: loading ? null : onRestore,
            child: Text(
              'Satın Alımları Geri Yükle',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      loading ? _textSec : _orange,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Otomatik yenilenir · İstediğiniz zaman iptal edebilirsiniz',
            textAlign: TextAlign.center,
            style:     TextStyle(
              fontSize: 11,
              color:    _textSec,
              height:   1.4,
            ),
          ),
        ],
      );
    });
  }
}
