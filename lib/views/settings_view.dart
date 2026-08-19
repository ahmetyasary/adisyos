import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/models/app_role.dart';
import 'package:orderix/navigation/app_sections.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/subscription_service.dart';
import 'package:orderix/views/paywall_sheet.dart';
import 'package:orderix/views/auth_screen.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';

const _privacyUrl = 'https://orderix.tr/privacy';
const _termsUrl = 'https://orderix.tr/terms';

// ── Design tokens ─────────────────────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);

// ──────────────────────────────────────────────────────────────
// SettingsView
// ──────────────────────────────────────────────────────────────

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _companyCtrl = TextEditingController();
  String _selectedLanguage = 'tr';
  bool _saving = false;
  Worker? _companyWorker;

  @override
  void initState() {
    super.initState();
    // Pre-fill from already-loaded value
    _companyCtrl.text = SettingsService.to.companyName.value;

    // If service is still loading, sync when it arrives
    _companyWorker = ever(SettingsService.to.companyName, (val) {
      if (mounted && _companyCtrl.text.isEmpty && val.isNotEmpty) {
        _companyCtrl.text = val;
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _selectedLanguage =
              prefs.getString('language') ?? (Get.locale?.languageCode ?? 'tr');
        });
      }
    });
  }

  @override
  void dispose() {
    _companyWorker?.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SettingsService.to.save(newCompanyName: _companyCtrl.text.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _selectedLanguage);
      if (mounted) {
        AppToast.success('Ayarlar kaydedildi', title: 'success'.tr);
        Get.back();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          _describeSaveError(e),
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Build a user-facing message that still includes enough detail to
  /// diagnose Supabase-side failures (missing constraint, RLS block, etc).
  String _describeSaveError(Object e) {
    const base = 'Ayarlar kaydedilemedi.';
    if (e is PostgrestException) {
      final parts = <String>[
        if (e.message.isNotEmpty) e.message,
        if ((e.details?.toString().isNotEmpty ?? false)) e.details.toString(),
        if ((e.code?.isNotEmpty ?? false)) 'code: ${e.code}',
      ];
      return parts.isEmpty ? base : '$base\n${parts.join(' · ')}';
    }
    final msg = e.toString();
    return msg.isEmpty ? base : '$base\n$msg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            _Header(embedded: widget.embedded),

            // ── Scrollable content ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Account card
                      _AccountCard(),
                      const SizedBox(height: 28),

                      // Subscription section
                      _SectionLabel('Abonelik'),
                      const SizedBox(height: 10),
                      const _SubscriptionCard(),
                      const SizedBox(height: 28),

                      // Business section
                      _SectionLabel('İşletme'),
                      const SizedBox(height: 10),
                      _Card(
                        child: Column(
                          children: [
                            _InlineField(
                              icon: CupertinoIcons.bag_fill,
                              label: 'Şirket Adı',
                              hint: 'Şirket adınızı girin',
                              controller: _companyCtrl,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const Divider(
                                height: 1,
                                color: _border,
                                indent: 16,
                                endIndent: 16),
                            const _CurrencyRow(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (AuthController.to.isAdmin) ...[
                        _SectionLabel('nav_order'.tr),
                        const SizedBox(height: 10),
                        _Card(
                          child: _NavOrderRow(
                            onTap: () => _showNavOrderSheet(context),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Language section
                      _SectionLabel('Dil'),
                      const SizedBox(height: 10),
                      _Card(
                        child: _LanguageRow(
                          value: _selectedLanguage,
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedLanguage = val);
                            Get.updateLocale(val == 'tr'
                                ? const Locale('tr', 'TR')
                                : const Locale('en', 'US'));
                          },
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Save button
                      _SaveButton(saving: _saving, onTap: _save),
                      const SizedBox(height: 28),

                      // Legal — privacy policy / terms (App Store requirement)
                      _SectionLabel('legal'.tr),
                      const SizedBox(height: 10),
                      const _LegalCard(),
                      const SizedBox(height: 28),

                      // Danger zone — in-app account deletion (App Store 5.1.1(v))
                      _SectionLabel('danger_zone'.tr),
                      const SizedBox(height: 10),
                      const _DeleteAccountCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _Header
// ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ShellLeading(embedded: embedded, color: _textPrimary),
            Text(
              'settings'.tr,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _AccountCard — shows logged-in user info
// ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = AuthController.to.user.value;
      final email = user?.email ?? '';
      final roleLabel = user?.role.name ?? '';
      final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB340), Color(0xFFFF9500)],
                ),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3DFF9500),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.split('@').first,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSec,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ──────────────────────────────────────────────────────────────
// Small helpers
// ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSec,
        letterSpacing: 1,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

// ── Inline text field row ──────────────────────────────────────

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  textCapitalization: textCapitalization,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: _textSec, fontSize: 14),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Currency row ───────────────────────────────────────────────

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow();

  static const _currencies = [
    ('₺', 'Türk Lirası'),
    ('\$', 'Dolar'),
    ('€', 'Euro'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = SettingsService.to.currencySymbol.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(CupertinoIcons.money_dollar,
                  size: 17, color: _orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para Birimi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textSec,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _currencies.map((c) {
                      final symbol = c.$1;
                      final label = c.$2;
                      final selected = symbol == current;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => SettingsService.to.setCurrency(symbol),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _orange : _bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _orange : _border,
                                width: 1.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: _orange.withOpacity(0.30),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3))
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  symbol,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        selected ? Colors.white : _textPrimary,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? Colors.white.withOpacity(0.90)
                                        : _textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Language row ───────────────────────────────────────────────

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onChanged});

  final String value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(CupertinoIcons.globe, size: 17, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dil',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                    icon: const Icon(CupertinoIcons.chevron_down,
                        size: 18, color: _textSec),
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Save button ────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB340), _orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44FF9500),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: saving ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'save_settings'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _LegalCard — privacy policy & terms of use links
// ──────────────────────────────────────────────────────────────

class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _LegalRow(
            icon: CupertinoIcons.lock_shield,
            label: 'privacy_policy'.tr,
            url: _privacyUrl,
          ),
          const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
          _LegalRow(
            icon: CupertinoIcons.doc_text,
            label: 'terms_of_use'.tr,
            url: _termsUrl,
          ),
        ],
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) AppToast.error('legal_link_failed'.tr);
    } catch (_) {
      AppToast.error('legal_link_failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: _orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ),
              const Icon(CupertinoIcons.arrow_up_right_square,
                  size: 16, color: _textSec),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _SubscriptionCard — shows plan status, trial countdown, restore
// ──────────────────────────────────────────────────────────────

const _green = Color(0xFF34C759);

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sub = SubscriptionService.to;
      final trial = sub.isInTrial;
      // "active" here means a full paid subscription (trial shown separately).
      final active = sub.isSubscribed && !trial;
      final days = sub.daysLeft;

      return _Card(
        child: Column(
          children: [
            // Status row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: active
                          ? _green.withValues(alpha: 0.12)
                          : trial
                              ? _orange.withValues(alpha: 0.12)
                              : const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      active
                          ? CupertinoIcons.checkmark_seal_fill
                          : trial
                              ? CupertinoIcons.hourglass
                              : CupertinoIcons.lock,
                      size: 17,
                      color: active
                          ? _green
                          : trial
                              ? _orange
                              : const Color(0xFFFF3B30),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? 'Pro Plan · Aktif'
                              : trial
                                  ? 'Deneme Dönemi'
                                  : 'Abonelik Gerekli',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? _green
                                : trial
                                    ? _orange
                                    : const Color(0xFFFF3B30),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active
                              ? 'Tüm özelliklere erişiminiz var'
                              : trial
                                  ? 'Ücretsiz deneme · $days gün kaldı'
                                  : 'Devam etmek için abone olun',
                          style: const TextStyle(fontSize: 12, color: _textSec),
                        ),
                      ],
                    ),
                  ),
                  if (!sub.isSubscribed)
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => showPaywallSheet(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Abone Ol',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Restore purchases row
            const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
            _RestoreRow(),
          ],
        ),
      );
    });
  }
}

class _RestoreRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final hasAccess = await SubscriptionService.to.restorePurchases();
          if (hasAccess) {
            AppToast.success('Abonelik başarıyla geri yüklendi');
          } else {
            AppToast.error('Aktif abonelik bulunamadı');
          }
        },
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(CupertinoIcons.arrow_clockwise,
                    size: 17, color: _orange),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Satın Alımları Geri Yükle',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary),
                ),
              ),
              const Icon(CupertinoIcons.chevron_forward,
                  size: 18, color: _textSec),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _DeleteAccountCard — App Store Guideline 5.1.1(v) compliance
// ──────────────────────────────────────────────────────────────

const _danger = Color(0xFFFF3B30);

class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _confirmDelete(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(CupertinoIcons.trash_fill,
                      size: 18, color: _danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'delete_account'.tr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'delete_account_subtitle'.tr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward, color: _textSec),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      iconColor: _danger,
      title: 'delete_account_title'.tr,
      message: 'delete_account_warning'.tr,
      confirmText: 'delete_account_confirm'.tr,
      cancelText: 'cancel'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    // Loading dialog — not dismissible while the network call runs.
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(color: _danger),
      ),
      barrierDismissible: false,
    );

    try {
      await AuthController.to.deleteAccount();
      StaffService.to.clearCurrentStaff();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.offAll(() => const AuthScreen());
      AppToast.success('delete_account_success'.tr);
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      // Surface the raw error for easier debugging during development.
      final detail =
          e is UnknownAuthException ? (e.detail ?? '') : e.toString();
      AppToast.error(
        detail.isEmpty
            ? 'delete_account_failed'.tr
            : '${'delete_account_failed'.tr}\n$detail',
        duration: const Duration(seconds: 6),
      );
    }
  }
}

// ── Sidebar order ──────────────────────────────────────────────

class _NavOrderRow extends StatelessWidget {
  const _NavOrderRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(CupertinoIcons.line_horizontal_3,
                    size: 17, color: _orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'nav_order'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'nav_order_hint'.tr,
                      style: const TextStyle(fontSize: 12, color: _textSec),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  size: 16, color: _textSec),
            ],
          ),
        ),
      ),
    );
  }
}

void _showNavOrderSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NavOrderSheet(),
  );
}

class _NavOrderSheet extends StatefulWidget {
  const _NavOrderSheet();

  @override
  State<_NavOrderSheet> createState() => _NavOrderSheetState();
}

class _NavOrderSheetState extends State<_NavOrderSheet> {
  late List<AppSection> _items;

  List<AppSection> get _defaultItems => appSections
      .where((s) => s.allows(AppRole.admin) && !s.hidden && !s.footer)
      .toList();

  @override
  void initState() {
    super.initState();
    _items = List<AppSection>.from(sectionsFor(AppRole.admin));
  }

  Future<void> _persist() =>
      SettingsService.to.setNavOrder(_items.map((s) => s.id).toList());

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'nav_order'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() => _items = _defaultItems);
                    await SettingsService.to.resetNavOrder();
                  },
                  child: Text(
                    'nav_order_reset'.tr,
                    style: const TextStyle(
                      color: _textSec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'sort_done'.tr,
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _items.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  color: _card,
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                _persist();
              },
              itemBuilder: (context, index) {
                final s = _items[index];
                return Container(
                  key: ValueKey(s.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            CupertinoIcons.line_horizontal_3,
                            size: 20,
                            color: _textSec,
                          ),
                        ),
                      ),
                      Icon(s.icon, size: 20, color: _orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.title(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
