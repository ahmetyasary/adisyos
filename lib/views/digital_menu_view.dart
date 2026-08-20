import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:orderix/services/digital_menu_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';

const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);
const _chip = Color(0xFFF2F2F7);

class DigitalMenuView extends StatefulWidget {
  const DigitalMenuView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DigitalMenuView> createState() => _DigitalMenuViewState();
}

class _DigitalMenuViewState extends State<DigitalMenuView> {
  @override
  void initState() {
    super.initState();
    MenuService.to.refresh();
    DigitalMenuService.to.load();
  }

  Future<void> _save() async {
    final ok = await DigitalMenuService.to.save();
    if (!mounted) return;
    if (ok) {
      AppToast.success('Dijital menü kaydedildi', title: 'success'.tr);
    } else {
      AppToast.error('Kaydedilemedi');
    }
  }

  Future<void> _copyLink() async {
    final url = DigitalMenuService.to.publicUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppToast.success('Bağlantı kopyalandı');
  }

  Future<void> _openPreview() async {
    final url = DigitalMenuService.to.publicUrl;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppToast.error('Bağlantı açılamadı');
  }

  Future<void> _regenerate() async {
    final ok = await DigitalMenuService.to.regenerateToken();
    if (!mounted) return;
    if (ok) {
      AppToast.success('Yeni QR bağlantısı oluşturuldu');
    } else {
      AppToast.error('Yenilenemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  ShellLeading(
                      embedded: widget.embedded, color: _textPrimary),
                  const Text(
                    'Dijital Menü',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final dm = DigitalMenuService.to;
              if (dm.loading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: _orange),
                );
              }
              final menus = MenuService.to.menus;
              final url = dm.publicUrl;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Yayında',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dm.enabled.value
                                          ? 'QR ile menü görüntülenebilir'
                                          : 'Menü bağlantısı kapalı',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: dm.enabled.value,
                                activeTrackColor: _orange,
                                onChanged: (v) => dm.setEnabled(v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('Menüde gösterilecekler'),
                      const SizedBox(height: 10),
                      if (menus.isEmpty)
                        const _Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Önce Menüler ekranından kategori ekleyin.',
                              style: TextStyle(color: _textSec, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        _Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < menus.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    color: _border,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                _MenuToggleRow(
                                  name: menus[i]['name'] as String,
                                  itemCount:
                                      ((menus[i]['items'] as List?) ?? const [])
                                          .length,
                                  selected: dm.selectedMenuIds
                                      .contains(menus[i]['id'] as int),
                                  onTap: () =>
                                      dm.toggleMenu(menus[i]['id'] as int),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: dm.saving.value ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: dm.saving.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Kaydet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _SectionLabel('QR kod'),
                      const SizedBox(height: 10),
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          child: Column(
                            children: [
                              if (url.isEmpty)
                                const Text(
                                  'Önce kaydedin',
                                  style: TextStyle(color: _textSec),
                                )
                              else ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                  ),
                                  child: QrImageView(
                                    data: url,
                                    version: QrVersions.auto,
                                    size: 200,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: _textPrimary,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  url,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textSec,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _copyLink,
                                        icon: const Icon(
                                          CupertinoIcons.doc_on_doc,
                                          size: 16,
                                        ),
                                        label: const Text('Kopyala'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _textPrimary,
                                          side:
                                              const BorderSide(color: _border),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _openPreview,
                                        icon: const Icon(
                                          CupertinoIcons.eye,
                                          size: 16,
                                        ),
                                        label: const Text('Önizle'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _orange,
                                          side: BorderSide(
                                              color: _orange.withValues(
                                                  alpha: 0.4)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: dm.saving.value
                                      ? null
                                      : _regenerate,
                                  child: const Text(
                                    'Bağlantıyı yenile',
                                    style: TextStyle(
                                      color: _textSec,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Müşteri QR’ı okuttuğunda seçtiğiniz menüler tarayıcıda açılır. Sipariş alınmaz; yalnızca görüntüleme.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSec,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

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
        border: const Border.fromBorderSide(
            BorderSide(color: _border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _MenuToggleRow extends StatelessWidget {
  const _MenuToggleRow({
    required this.name,
    required this.itemCount,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int itemCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? _orange : _chip,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? null
                      : Border.all(color: _border),
                ),
                child: selected
                    ? const Icon(CupertinoIcons.checkmark,
                        size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '$itemCount ürün',
                      style: const TextStyle(fontSize: 12, color: _textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
