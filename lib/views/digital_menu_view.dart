import 'package:barcode/barcode.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:orderix/services/digital_menu_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/themes/app_colors.dart';

Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.border;
Color get _chip => AppColors.chipBg;

class DigitalMenuView extends StatefulWidget {
  const DigitalMenuView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DigitalMenuView> createState() => _DigitalMenuViewState();
}

class _DigitalMenuViewState extends State<DigitalMenuView> {
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    MenuService.to.refresh();
    TableService.to.refresh();
    DigitalMenuService.to.load();
  }

  Map<String, dynamic>? get _selectedTable {
    final id = DigitalMenuService.to.selectedTableId.value;
    if (id == null) return null;
    for (final t in TableService.to.tables) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  String get _currentUrl {
    final dm = DigitalMenuService.to;
    final table = _selectedTable;
    if (table == null) return dm.publicUrl();
    return dm.publicUrl(
      tableId: table['id'] as int,
      tableName: table['name'] as String,
    );
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
    final url = _currentUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppToast.success('Bağlantı kopyalandı');
  }

  Future<void> _openPreview() async {
    final url = _currentUrl;
    if (url.isEmpty) return;
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppToast.error('Bağlantı açılamadı');
  }

  Future<void> _regenerate() async {
    final confirmed = await AppDialog.confirm(
      icon: CupertinoIcons.qrcode,
      iconColor: _orange,
      title: 'Bağlantıyı yenile',
      message:
          'QR bağlantıları yenilenecek. Emin misiniz?\nEski QR kodlar artık çalışmaz.',
      confirmText: 'Yenile',
      cancelText: 'Vazgeç',
      destructive: true,
    );
    if (!confirmed) return;

    final ok = await DigitalMenuService.to.regenerateToken();
    if (!mounted) return;
    if (ok) {
      AppToast.success('Yeni QR bağlantısı oluşturuldu');
    } else {
      AppToast.error('Yenilenemedi');
    }
  }

  Future<void> _printCurrent() async {
    final table = _selectedTable;
    if (table == null) {
      AppToast.warning('Önce bir masa seçin');
      return;
    }
    await _printStickers([table]);
  }

  Future<void> _printAllTables() async {
    final tables = TableService.to.tables.toList();
    if (tables.isEmpty) {
      AppToast.warning('Henüz masa yok');
      return;
    }
    await _printStickers(tables);
  }

  Future<void> _printStickers(List<Map<String, dynamic>> tables) async {
    final dm = DigitalMenuService.to;
    if (dm.token.value.isEmpty) {
      AppToast.warning('Önce dijital menüyü kaydedin');
      return;
    }
    setState(() => _printing = true);
    try {
      final company = SettingsService.to.companyName.value.trim().isEmpty
          ? 'Orderix'
          : SettingsService.to.companyName.value.trim();
      final regular = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      final doc = pw.Document();

      for (final table in tables) {
        final id = table['id'] as int;
        final name = table['name'] as String;
        final url = dm.publicUrl(tableId: id, tableName: name);
        final code = dm.barcodePayload(tableId: id);
        final qrPng = await _qrPng(url);
        final barcodeSvg = Barcode.code128().toSvg(
          code,
          width: 220,
          height: 48,
          drawText: false,
        );

        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
            margin: const pw.EdgeInsets.all(10),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  company,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFF4E0),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    name,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 14,
                      color: PdfColor.fromInt(0xFFFF9500),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Menü için QR okutun',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 6),
                pw.Image(pw.MemoryImage(qrPng), width: 110, height: 110),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Barkod',
                  style: pw.TextStyle(
                      font: regular, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 4),
                pw.SvgImage(svg: barcodeSvg, width: 180, height: 40),
                pw.SizedBox(height: 4),
                pw.Text(
                  code,
                  style: pw.TextStyle(font: regular, fontSize: 7),
                ),
              ],
            ),
          ),
        );
      }

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) AppToast.error('Yazdırılamadı');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<Uint8List> _qrPng(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF1C1C1E),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF1C1C1E),
      ),
    );
    final image = await painter.toImageData(512);
    return image!.buffer.asUint8List();
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
            decoration: BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  ShellLeading(
                      embedded: widget.embedded, color: _textPrimary),
                  Text(
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
              // Touch reactive lists.
              final tables = TableService.to.tables.toList();
              final menus = MenuService.to.menus;
              final selectedId = dm.selectedTableId.value;
              if (dm.loading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: _orange),
                );
              }
              final url = _currentUrl;
              final table = _selectedTable;
              final notice = dm.syncNotice.value;
              // Rebuild QR whenever the shared token changes on any device.
              dm.token.value;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (notice.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _orange.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.arrow_2_circlepath,
                                  size: 18, color: _orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  notice,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
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
                                      style: TextStyle(
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
                        _Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
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
                                  Divider(
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
                      const _SectionLabel('Masa QR / barkod'),
                      const SizedBox(height: 10),
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Masa seçin',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Her masa kendi QR’ına sahip olur. Müşteri bu masadan sipariş gönderebilir.',
                                style: TextStyle(fontSize: 12, color: _textSec),
                              ),
                              const SizedBox(height: 12),
                              if (tables.isEmpty)
                                Text(
                                  'Henüz masa yok. Masalar ekranından ekleyin.',
                                  style: TextStyle(color: _textSec, fontSize: 13),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final t in tables)
                                      ChoiceChip(
                                        label: Text(t['name'] as String),
                                        selected: selectedId == t['id'],
                                        selectedColor:
                                            _orange.withValues(alpha: 0.18),
                                        labelStyle: TextStyle(
                                          color: selectedId == t['id']
                                              ? _orange
                                              : _textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        side: BorderSide(
                                          color: selectedId == t['id']
                                              ? _orange
                                              : _border,
                                        ),
                                        onSelected: (_) {
                                          dm.selectedTableId.value =
                                              t['id'] as int;
                                        },
                                      ),
                                  ],
                                ),
                              if (url.isNotEmpty && table != null) ...[
                                const SizedBox(height: 18),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF4E0),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            table['name'] as String,
                                            style: const TextStyle(
                                              color: _orange,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        QrImageView(
                                          data: url,
                                          version: QrVersions.auto,
                                          size: 200,
                                          eyeStyle: QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: _textPrimary,
                                          ),
                                          dataModuleStyle:
                                              QrDataModuleStyle(
                                            dataModuleShape:
                                                QrDataModuleShape.square,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  url,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textSec,
                                  ),
                                ),
                                const SizedBox(height: 14),
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
                                        style: _outlineStyle(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _openPreview,
                                        icon: const Icon(
                                          CupertinoIcons.eye,
                                          size: 16,
                                        ),
                                        label: const Text('Önizle'),
                                        style: _outlineStyle(orange: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: _printing ? null : _printCurrent,
                                    icon: _printing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            CupertinoIcons.barcode,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _printing
                                          ? 'Hazırlanıyor…'
                                          : 'Barkod / QR yazdır',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _textPrimary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (url.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 14),
                                  child: Text(
                                    'QR ve barkod için yukarıdan masa seçin.',
                                    style:
                                        TextStyle(color: _textSec, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              if (tables.isNotEmpty && url.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _printing ? null : _printAllTables,
                                  child: const Text(
                                    'Tüm masalar için yazdır',
                                    style: TextStyle(
                                      color: _orange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              TextButton(
                                onPressed:
                                    dm.saving.value ? null : _regenerate,
                                child: Text(
                                  'Bağlantıyı yenile',
                                  style: TextStyle(
                                    color: _textSec,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Müşteri masa QR’ından ürün seçip sipariş gönderir. Onay bekleyenler sol menüde görünür.',
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

  ButtonStyle _outlineStyle({bool orange = false}) {
    return OutlinedButton.styleFrom(
      foregroundColor: orange ? _orange : _textPrimary,
      side: BorderSide(color: orange ? _orange.withValues(alpha: 0.4) : _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      style: TextStyle(
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
        border:
            Border.fromBorderSide(BorderSide(color: _border, width: 1)),
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
                  border: selected ? null : Border.all(color: _border),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '$itemCount ürün',
                      style: TextStyle(fontSize: 12, color: _textSec),
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
