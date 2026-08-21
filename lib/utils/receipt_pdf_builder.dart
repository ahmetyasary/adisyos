import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:orderix/models/receipt_layout.dart';

/// Builds a tenant-styled adisyon PDF for preview / AirPrint.
class ReceiptPdfBuilder {
  ReceiptPdfBuilder._();

  static PdfPageFormat pageFormatFor(String paperSize) {
    switch (paperSize) {
      case 'roll58':
        return PdfPageFormat.roll57;
      case 'a4':
        return PdfPageFormat.a4;
      case 'roll80':
      default:
        return PdfPageFormat.roll80;
    }
  }

  /// Finite paper size for iOS print dialog (infinite roll height confuses AirPrint).
  static PdfPageFormat printJobFormatFor(String paperSize) {
    switch (paperSize) {
      case 'roll58':
        return const PdfPageFormat(
          57 * PdfPageFormat.mm,
          400 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        );
      case 'a4':
        return PdfPageFormat.a4;
      case 'roll80':
      default:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          400 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        );
    }
  }

  static String paperSizeLabel(String paperSize) {
    switch (paperSize) {
      case 'roll58':
        return '58 mm';
      case 'a4':
        return 'A4';
      case 'roll80':
      default:
        return '80 mm';
    }
  }

  static Future<Uint8List> build({
    required ReceiptLayout layout,
    required String companyName,
    required String tableLabel,
    required String currencySymbol,
    required List<Map<String, dynamic>> orders,
    required double subtotal,
    required double discount,
    required double finalTotal,
    PdfPageFormat? pageFormat,
  }) async {
    final format = pageFormat ?? pageFormatFor(layout.paperSize);
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final titleSize = layout.titleFont;
    final bodySize = layout.bodyFont;
    final metaSize = layout.metaFont;
    final totalSize = layout.totalFont;
    final headerNote = layout.headerNote.trim();
    final footer = layout.footerText.trim().isEmpty
        ? 'Teşekkür ederiz!'
        : layout.footerText.trim();
    final cs = currencySymbol;

    final doc = pw.Document();
    final isWide = layout.paperSize == 'a4';
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: isWide
            ? const pw.EdgeInsets.all(24)
            : const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          final children = <pw.Widget>[];

          if (layout.showCompanyName) {
            children.add(
              pw.Center(
                child: pw.Text(
                  companyName,
                  style: pw.TextStyle(font: boldFont, fontSize: titleSize),
                ),
              ),
            );
          }
          if (headerNote.isNotEmpty) {
            children.add(
              pw.Center(
                child: pw.Text(
                  headerNote,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regularFont, fontSize: metaSize),
                ),
              ),
            );
          }
          if (layout.showTable) {
            children.add(
              pw.Center(
                child: pw.Text(
                  tableLabel,
                  style: pw.TextStyle(font: regularFont, fontSize: bodySize),
                ),
              ),
            );
          }
          if (layout.showDateTime) {
            children.add(
              pw.Center(
                child: pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: pw.TextStyle(font: regularFont, fontSize: metaSize),
                ),
              ),
            );
          }

          if (layout.showItems ||
              layout.showDiscountBreakdown ||
              layout.showTotal) {
            children.add(pw.SizedBox(height: 8));
            children.add(pw.Divider());
            children.add(pw.SizedBox(height: 4));
          }

          if (layout.showItems) {
            for (final order in orders) {
              children.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${order['quantity']}x  ${order['name']}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: bodySize),
                        ),
                      ),
                      pw.Text(
                        '$cs${((order['price'] as num).toDouble() * (order['quantity'] as int)).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            font: regularFont, fontSize: bodySize),
                      ),
                    ],
                  ),
                ),
              );
            }
            children.add(pw.SizedBox(height: 4));
            children.add(pw.Divider());
            children.add(pw.SizedBox(height: 4));
          }

          if (layout.showDiscountBreakdown && discount > 0) {
            children.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ara Toplam',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: bodySize - 1)),
                  pw.Text('$cs${subtotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: bodySize - 1)),
                ],
              ),
            );
            children.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('İndirim',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: bodySize - 1)),
                  pw.Text('-$cs${discount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: bodySize - 1)),
                ],
              ),
            );
          }

          if (layout.showTotal) {
            children.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOPLAM',
                      style:
                          pw.TextStyle(font: boldFont, fontSize: totalSize)),
                  pw.Text('$cs${finalTotal.toStringAsFixed(2)}',
                      style:
                          pw.TextStyle(font: boldFont, fontSize: totalSize)),
                ],
              ),
            );
          }

          if (layout.showFooter) {
            children.add(pw.SizedBox(height: 16));
            children.add(
              pw.Center(
                child: pw.Text(
                  footer,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      font: regularFont, fontSize: bodySize - 1),
                ),
              ),
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );

    return doc.save();
  }
}
