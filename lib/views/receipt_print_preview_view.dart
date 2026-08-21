import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/utils/receipt_pdf_builder.dart';
import 'package:orderix/widgets/app_toast.dart';

const _bg = Color(0xFFF2F2F7);
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);

/// In-app adisyon preview before handing off to the system print sheet.
class ReceiptPrintPreviewView extends StatefulWidget {
  const ReceiptPrintPreviewView({
    super.key,
    required this.tableLabel,
    required this.orders,
    required this.subtotal,
    required this.discount,
    required this.finalTotal,
  });

  final String tableLabel;
  final List<Map<String, dynamic>> orders;
  final double subtotal;
  final double discount;
  final double finalTotal;

  @override
  State<ReceiptPrintPreviewView> createState() =>
      _ReceiptPrintPreviewViewState();
}

class _ReceiptPrintPreviewViewState extends State<ReceiptPrintPreviewView> {
  Uint8List? _pdfBytes;
  ui.Image? _previewImage;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _buildPreview();
  }

  @override
  void dispose() {
    _previewImage?.dispose();
    super.dispose();
  }

  Future<void> _buildPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final layout = SettingsService.to.receiptLayout.value;
      final companyName = SettingsService.to.companyName.value.isNotEmpty
          ? SettingsService.to.companyName.value
          : 'Orderix';
      final bytes = await ReceiptPdfBuilder.build(
        layout: layout,
        companyName: companyName,
        tableLabel: widget.tableLabel,
        currencySymbol: SettingsService.cs,
        orders: widget.orders,
        subtotal: widget.subtotal,
        discount: widget.discount,
        finalTotal: widget.finalTotal,
        pageFormat: ReceiptPdfBuilder.printJobFormatFor(layout.paperSize),
      );
      ui.Image? image;
      await for (final page in Printing.raster(bytes, dpi: 150)) {
        image = await page.toImage();
        break;
      }
      if (!mounted) {
        image?.dispose();
        return;
      }
      _previewImage?.dispose();
      setState(() {
        _pdfBytes = bytes;
        _previewImage = image;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _sendToPrinter() async {
    final bytes = _pdfBytes;
    if (bytes == null || _sending) return;
    setState(() => _sending = true);
    try {
      final layout = SettingsService.to.receiptLayout.value;
      final jobFormat =
          ReceiptPdfBuilder.printJobFormatFor(layout.paperSize);
      await Printing.layoutPdf(
        name: 'Adisyon · ${widget.tableLabel}',
        format: jobFormat,
        dynamicLayout: false,
        forceCustomPrintPaper: true,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      AppToast.error('Yazdırma başlatılamadı: $e', title: 'error'.tr);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = SettingsService.to.receiptLayout.value;
    final paperLabel = ReceiptPdfBuilder.paperSizeLabel(layout.paperSize);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: topPad),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(CupertinoIcons.xmark, color: _textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      'Yazdırma önizlemesi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tableLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Kağıt · $paperLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kontrol edin, ardından yazıcıya gönderin.',
                style: TextStyle(fontSize: 13, color: _textSec),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _orange),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Önizleme oluşturulamadı.\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _textSec),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: layout.paperSize == 'a4' ? 420 : 280,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: _previewImage == null
                                    ? const SizedBox(height: 200)
                                    : RawImage(
                                        image: _previewImage,
                                        fit: BoxFit.fitWidth,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (_loading || _pdfBytes == null || _sending)
                      ? null
                      : _sendToPrinter,
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.printer_fill, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Yazıcıya gönder',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
