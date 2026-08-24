import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:orderix/models/integrations_config.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/utils/app_haptics.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';

Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.border;

Future<void> openPosIntegration(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PosIntegrationView()),
  );
}

Future<void> openMarketplaceIntegration(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const MarketplaceIntegrationView()),
  );
}

class PosIntegrationView extends StatefulWidget {
  const PosIntegrationView({super.key});

  @override
  State<PosIntegrationView> createState() => _PosIntegrationViewState();
}

class _PosIntegrationViewState extends State<PosIntegrationView> {
  late bool _enabled;
  late PosProvider _provider;
  late final TextEditingController _merchant;
  late final TextEditingController _terminal;
  late final TextEditingController _apiKey;
  late final TextEditingController _endpoint;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pos = SettingsService.to.integrations.value.pos;
    _enabled = pos.enabled;
    _provider = pos.provider;
    _merchant = TextEditingController(text: pos.merchantId);
    _terminal = TextEditingController(text: pos.terminalId);
    _apiKey = TextEditingController(text: pos.apiKey);
    _endpoint = TextEditingController(text: pos.endpoint);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _terminal.dispose();
    _apiKey.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final next = SettingsService.to.integrations.value.copyWith(
      pos: PosIntegrationConfig(
        enabled: _enabled,
        provider: _provider,
        merchantId: _merchant.text.trim(),
        terminalId: _terminal.text.trim(),
        apiKey: _apiKey.text.trim(),
        endpoint: _endpoint.text.trim(),
      ),
    );
    await SettingsService.to.setIntegrations(next);
    if (!mounted) return;
    setState(() => _saving = false);
    AppHaptics.success();
    AppToast.success('POS ayarları kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _SubHeader(
            topPad: top,
            title: 'POS Entegrasyonu',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoBanner(
                        text:
                            'Yazar kasa / ÖKC bağlantısı. Canlı satış aktarımı için cihaz üreticisi veya ödeme sağlayıcınızın API bilgilerini girin.',
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(
                            'POS bağlantısını aç',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _enabled
                                ? 'Siparişler POS’a iletilebilir'
                                : 'Kapalı — sadece Orderix içinde kalır',
                            style: TextStyle(fontSize: 12, color: _textSec),
                          ),
                          activeThumbColor: _orange,
                          value: _enabled,
                          onChanged: (v) {
                            AppHaptics.selection();
                            setState(() => _enabled = v);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sağlayıcı',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textSec,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<PosProvider>(
                                value: _provider,
                                dropdownColor: _card,
                                decoration: _fieldDeco(),
                                items: [
                                  for (final p in PosProvider.values)
                                    DropdownMenuItem(
                                      value: p,
                                      child: Text(p.label),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _provider = v);
                                },
                              ),
                              const SizedBox(height: 14),
                              _LabeledField(
                                label: 'İşyeri / Merchant ID',
                                controller: _merchant,
                                hint: 'Örn. 123456',
                              ),
                              const SizedBox(height: 12),
                              _LabeledField(
                                label: 'Terminal / Cihaz ID',
                                controller: _terminal,
                                hint: 'Örn. TERM-01',
                              ),
                              const SizedBox(height: 12),
                              _LabeledField(
                                label: 'API anahtarı',
                                controller: _apiKey,
                                hint: 'Partner API key',
                                obscure: _obscureKey,
                                suffix: IconButton(
                                  onPressed: () => setState(
                                      () => _obscureKey = !_obscureKey),
                                  icon: Icon(
                                    _obscureKey
                                        ? CupertinoIcons.eye
                                        : CupertinoIcons.eye_slash,
                                    size: 18,
                                    color: _textSec,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _LabeledField(
                                label: 'Özel endpoint (opsiyonel)',
                                controller: _endpoint,
                                hint: 'https://…',
                                keyboardType: TextInputType.url,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Kaydediliyor…' : 'Kaydet',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class MarketplaceIntegrationView extends StatefulWidget {
  const MarketplaceIntegrationView({super.key});

  @override
  State<MarketplaceIntegrationView> createState() =>
      _MarketplaceIntegrationViewState();
}

class _MarketplaceIntegrationViewState
    extends State<MarketplaceIntegrationView> {
  late Map<MarketplaceChannel, _MarketDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = SettingsService.to.integrations.value;
    _drafts = {
      for (final c in MarketplaceChannel.values)
        c: _MarketDraft.from(cfg.channel(c)),
    };
  }

  @override
  void dispose() {
    for (final d in _drafts.values) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final list = [
      for (final c in MarketplaceChannel.values) _drafts[c]!.toConfig(c),
    ];
    final next =
        SettingsService.to.integrations.value.copyWith(marketplaces: list);
    await SettingsService.to.setIntegrations(next);
    if (!mounted) return;
    setState(() => _saving = false);
    AppHaptics.success();
    AppToast.success('Pazaryeri ayarları kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _SubHeader(
            topPad: top,
            title: 'Pazaryeri',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoBanner(
                        text:
                            'Getir, Trendyol Go (Uber Eats) ve Yemeksepeti siparişlerini Orderix’e almak için restoran paneli bilgilerini girin. Canlı webhook bağlantısı partner onayından sonra açılır.',
                      ),
                      const SizedBox(height: 16),
                      for (final c in MarketplaceChannel.values) ...[
                        _MarketplaceCard(
                          channel: c,
                          draft: _drafts[c]!,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Kaydediliyor…' : 'Kaydet',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _MarketDraft {
  _MarketDraft({
    required this.enabled,
    required this.restaurantId,
    required this.apiKey,
    required this.apiSecret,
  });

  factory _MarketDraft.from(MarketplaceIntegrationConfig c) => _MarketDraft(
        enabled: c.enabled,
        restaurantId: TextEditingController(text: c.restaurantId),
        apiKey: TextEditingController(text: c.apiKey),
        apiSecret: TextEditingController(text: c.apiSecret),
      );

  bool enabled;
  final TextEditingController restaurantId;
  final TextEditingController apiKey;
  final TextEditingController apiSecret;
  bool obscureKey = true;
  bool obscureSecret = true;

  void dispose() {
    restaurantId.dispose();
    apiKey.dispose();
    apiSecret.dispose();
  }

  MarketplaceIntegrationConfig toConfig(MarketplaceChannel channel) =>
      MarketplaceIntegrationConfig(
        channel: channel,
        enabled: enabled,
        restaurantId: restaurantId.text.trim(),
        apiKey: apiKey.text.trim(),
        apiSecret: apiSecret.text.trim(),
      );
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.channel,
    required this.draft,
    required this.onChanged,
  });

  final MarketplaceChannel channel;
  final _MarketDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = draft.toConfig(channel).statusLabel;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    CupertinoIcons.bag_fill,
                    color: _orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        channel.subtitle,
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: status),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Aktif et',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              activeThumbColor: _orange,
              value: draft.enabled,
              onChanged: (v) {
                AppHaptics.selection();
                draft.enabled = v;
                onChanged();
              },
            ),
            _LabeledField(
              label: 'Restoran / mağaza ID',
              controller: draft.restaurantId,
              hint: channel.brandHint,
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'API anahtarı',
              controller: draft.apiKey,
              obscure: draft.obscureKey,
              suffix: IconButton(
                onPressed: () {
                  draft.obscureKey = !draft.obscureKey;
                  onChanged();
                },
                icon: Icon(
                  draft.obscureKey
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  size: 18,
                  color: _textSec,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'API secret',
              controller: draft.apiSecret,
              obscure: draft.obscureSecret,
              suffix: IconButton(
                onPressed: () {
                  draft.obscureSecret = !draft.obscureSecret;
                  onChanged();
                },
                icon: Icon(
                  draft.obscureSecret
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  size: 18,
                  color: _textSec,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.topPad,
    required this.title,
    required this.onBack,
  });

  final double topPad;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPad, left: 4, right: 8),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(CupertinoIcons.back, color: _textPrimary),
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.info_circle_fill,
              color: _orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final active = label == 'Aktif';
    final color = active ? const Color(0xFF34C759) : _textSec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textSec,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: _textPrimary, fontSize: 15),
          decoration: _fieldDeco(hint: hint, suffix: suffix),
        ),
      ],
    );
  }
}

InputDecoration _fieldDeco({String? hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _textSec.withValues(alpha: 0.7), fontSize: 14),
    filled: true,
    fillColor: AppColors.chipBg,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _orange, width: 1.4),
    ),
  );
}
