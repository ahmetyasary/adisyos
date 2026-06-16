import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

// Legal links (App Store Guideline 3.1.2 — must be functional on the paywall).
const _privacyUrl = 'https://orderix.tr/privacy';
const _termsUrl   = 'https://orderix.tr/terms';

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

  /// Per-month equivalent of the yearly plan, e.g. "≈ ₺16,66/ay", shown under
  /// the yearly price so the annual value reads at a glance (Apple-style).
  ///
  /// We mirror the storefront's own formatting by lifting the currency symbol
  /// and decimal separator out of the yearly `priceString`, so it matches the
  /// locale shown elsewhere on the sheet without hard-coding a currency.
  String? get _yearlyPerMonth {
    final y = _yearly?.storeProduct;
    if (y == null || y.price <= 0) return null;
    final perMonth = y.price / 12.0;
    final symbol = y.priceString.replaceAll(RegExp(r'[\d.,\s ]'), '').trim();
    final ps = y.priceString;
    final dec = RegExp(r'[.,]\d{1,2}(?!\d)').allMatches(ps).toList();
    final usesComma =
        dec.isNotEmpty ? ps[dec.last.start] == ',' : ps.contains('.');
    final number =
        NumberFormat('#,##0.00', usesComma ? 'tr' : 'en').format(perMonth);
    if (symbol.isEmpty) return '≈ $number/ay';
    final symbolFirst = y.priceString.trimLeft().startsWith(symbol);
    return symbolFirst ? '≈ $symbol$number/ay' : '≈ $number $symbol/ay';
  }

  // ── StoreKit introductory free-trial offer (selected plan) ──────

  IntroductoryPrice? get _selectedIntro =>
      _selected?.storeProduct.introductoryPrice;

  /// Whether the selected plan carries a *free* introductory trial.
  bool get _hasFreeTrial {
    final intro = _selectedIntro;
    return intro != null && intro.price <= 0;
  }

  /// Localised free-trial headline for the selected plan, e.g.
  /// "İlk 14 gün ücretsiz". Null when the plan has no free trial.
  String? get _trialHeadline {
    final intro = _selectedIntro;
    if (intro == null || intro.price > 0) return null;
    return 'İlk ${intro.periodNumberOfUnits} '
        '${_unitLabel(intro.periodUnit)} ücretsiz';
  }

  /// What the trial converts to, e.g. "Sonra ₺149,99/ay olarak yenilenir".
  String? get _renewLine {
    final pkg = _selected;
    if (pkg == null) return null;
    return 'Sonra ${pkg.storeProduct.priceString}/$_selectedPeriodLabel '
        'olarak yenilenir';
  }

  String get _selectedPeriodLabel => _selectedIdx == 0 ? 'ay' : 'yıl';

  String _unitLabel(PeriodUnit unit) {
    switch (unit) {
      case PeriodUnit.day:   return 'gün';
      case PeriodUnit.week:  return 'hafta';
      case PeriodUnit.month: return 'ay';
      case PeriodUnit.year:  return 'yıl';
      case PeriodUnit.unknown: return 'gün';
    }
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
    } on PlatformException catch (e) {
      // Cancellation/already-purchased are handled inside purchasePackage;
      // anything that reaches here is a genuine failure.
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
      AppToast.error(
        e.message ?? 'Satın alma tamamlanamadı. Lütfen tekrar deneyin.',
      );
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
                const SizedBox(height: 14),

                // App icon + brand
                const _BrandHero(),
                const SizedBox(height: 16),

                // Trial expired banner (lockout only)
                if (!widget.dismissible) ...[
                  const _TrialExpiredBanner(),
                  const SizedBox(height: 12),
                ],

                // Feature list
                const _FeatureList(),
                const SizedBox(height: 16),

                // Plan selector
                if (_loading)
                  const _PlanLoading()
                else
                  _PlanRow(
                    monthly:        _monthly,
                    yearly:         _yearly,
                    savingsBadge:   _savingsBadge,
                    yearlyPerMonth: _yearlyPerMonth,
                    selectedIndex:  _selectedIdx,
                    onSelect:       (i) => setState(() => _selectedIdx = i),
                  ),
                const SizedBox(height: 14),

                // CTA — the free-trial offer is surfaced directly on the button
                // (headline + what it renews to), StoreKit-driven.
                _CtaButton(
                  package:    _selected,
                  onPurchase: _onPurchase,
                  title:      _hasFreeTrial
                      ? (_trialHeadline ?? 'Ücretsiz Denemeyi Başlat')
                      : 'Aboneliği Başlat',
                  subtitle:   _hasFreeTrial ? _renewLine : null,
                ),
                const SizedBox(height: 12),

                // Restore + legal
                _Footer(onRestore: _onRestore, showTrialTerms: _hasFreeTrial),

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
        SizedBox(
          width:  56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize:      25,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: _orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Orderix\'i kullanmaya devam etmek için aboneliğinizi başlatın.',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      _textPrimary,
                height:     1.3,
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
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width:  22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: _orange),
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
    required this.yearlyPerMonth,
    required this.selectedIndex,
    required this.onSelect,
  });

  final Package? monthly;
  final Package? yearly;
  final String?  savingsBadge;
  final String?  yearlyPerMonth;
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

    // Top padding leaves room for the yearly card's "best value" ribbon,
    // which is positioned to overhang the card's top edge.
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IntrinsicHeight(
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
                  onTap:    () => onSelect(0),
                ),
              ),
            if (monthly != null && yearly != null)
              const SizedBox(width: 12),
            if (yearly != null)
              Expanded(
                child: _PlanCard(
                  label:    'Yıllık',
                  price:    yearly!.storeProduct.priceString,
                  period:   'her yıl',
                  selected: selectedIndex == 1,
                  ribbon:   savingsBadge,
                  subPrice: yearlyPerMonth,
                  onTap:    () => onSelect(1),
                ),
              ),
          ],
        ),
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
    required this.onTap,
    this.ribbon,
    this.subPrice,
  });

  final String  label;
  final String  price;
  final String  period;
  final bool    selected;
  final VoidCallback onTap;

  /// "Best value" pill that overhangs the top edge (e.g. "%17 İNDİRİM").
  final String? ribbon;

  /// Secondary price line under the period (e.g. "≈ ₺16,66/ay").
  final String? subPrice;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve:    Curves.easeOut,
            padding:  const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _orange : _border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color:      _orange.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset:     const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color:      const Color(0x08000000),
                        blurRadius: 10,
                        offset:     const Offset(0, 3),
                      ),
                    ],
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
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
                const SizedBox(height: 12),

                // Price
                Text(
                  price,
                  style: const TextStyle(
                    fontSize:      21,
                    fontWeight:    FontWeight.w800,
                    color:         _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),

                // Period
                Text(
                  period,
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w500,
                    color:      _textSec,
                  ),
                ),

                // Per-month equivalent (yearly only)
                if (subPrice != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subPrice!,
                    style: TextStyle(
                      fontSize:   11.5,
                      fontWeight: FontWeight.w700,
                      color:      selected ? _orange : _textSec,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // "Best value" ribbon, overhanging the top edge.
          if (ribbon != null)
            Positioned(
              top:   -11,
              left:  0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        _orange,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color:      _orange.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    ribbon!.toUpperCase(),
                    style: const TextStyle(
                      fontSize:      10,
                      fontWeight:    FontWeight.w800,
                      color:         Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _CtaButton — two-line: headline + (optional) renewal note
// ──────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.package,
    required this.onPurchase,
    required this.title,
    this.subtitle,
  });

  final Package?     package;
  final VoidCallback onPurchase;
  final String       title;
  final String?      subtitle;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = SubscriptionService.to.isPurchasing.value;
      final enabled = package != null && !loading;

      return GestureDetector(
        onTap: enabled ? onPurchase : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: subtitle != null ? 62 : 54,
          width:  double.infinity,
          decoration: BoxDecoration(
            color:        enabled ? _orange : const Color(0xFFD1D1D6),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color:      _orange.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset:     const Offset(0, 8),
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
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize:      16,
                          fontWeight:    FontWeight.w700,
                          color:         Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize:   11.5,
                            fontWeight: FontWeight.w500,
                            color:      Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
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
  const _Footer({required this.onRestore, this.showTrialTerms = false});
  final VoidCallback onRestore;
  final bool         showTrialTerms;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = SubscriptionService.to.isPurchasing.value;
      return Column(
        children: [
          // Auto-renew + cancellation disclosure (App Store Guideline 3.1.2).
          // The trial→paid conversion and renewal price are already on the CTA,
          // so this stays to the essential consumer-protection wording.
          Text(
            showTrialTerms
                ? 'Deneme bitmeden iptal etmezsen otomatik olarak ücretli '
                    'plana geçer. İstediğin zaman App Store\'dan iptal edebilirsin.'
                : 'Abonelik otomatik yenilenir. İstediğin zaman App Store\'dan '
                    'iptal edebilirsin.',
            textAlign: TextAlign.center,
            style:     const TextStyle(
              fontSize: 11,
              color:    _textSec,
              height:   1.4,
            ),
          ),
          const SizedBox(height: 10),

          // Legal consent — App Store Guideline 3.1.2
          const _PaywallLegal(),
          const SizedBox(height: 12),

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
        ],
      );
    });
  }
}

// ──────────────────────────────────────────────────────────────
// _PaywallLegal — EULA + Privacy consent with functional links
// ──────────────────────────────────────────────────────────────

class _PaywallLegal extends StatelessWidget {
  const _PaywallLegal();

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 11,
      color:    _textSec,
      height:   1.5,
    );
    const linkStyle = TextStyle(
      fontSize:        11,
      fontWeight:      FontWeight.w600,
      color:           _orange,
      decoration:      TextDecoration.underline,
      decorationColor: _orange,
      height:          1.5,
    );

    // Single wrapped line keeps the required EULA + Privacy links functional
    // (Guideline 3.1.2) without spending two extra rows of vertical space.
    return Wrap(
      alignment:          WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Devam ederek ', style: textStyle),
        GestureDetector(
          onTap: () => _open(_termsUrl),
          child: const Text('Kullanım Koşulları', style: linkStyle),
        ),
        const Text(' ve ', style: textStyle),
        GestureDetector(
          onTap: () => _open(_privacyUrl),
          child: const Text('Gizlilik Politikası', style: linkStyle),
        ),
        const Text('\'nı kabul edersin.', style: textStyle),
      ],
    );
  }
}
