import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext, RenderBox, Offset;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Border, Row;
import 'package:syncfusion_officechart/officechart.dart';

import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/widgets/app_toast.dart';

/// Builds detailed Excel workbooks (with charts) for daily / monthly / yearly
/// reports and shares the resulting `.xlsx` file.
class ReportExcelExporter {
  ReportExcelExporter._();

  static final _dateFmt = DateFormat('dd.MM.yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _fileStamp = DateFormat('yyyyMMdd_HHmm');

  static Future<void> exportDaily(
    DateTime day, {
    Rect? shareOrigin,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final sales = SalesHistoryService.to.getSalesForDate(d);
    if (sales.isEmpty) {
      AppToast.warning('Bu gün için satış yok', title: 'Excel');
      return;
    }

    try {
      final workbook = Workbook(0);
      final summary = workbook.worksheets.addWithName('Özet');
      final detail = workbook.worksheets.addWithName('Satışlar');
      final products = workbook.worksheets.addWithName('Ürünler');

      final total = SalesHistoryService.to.getTotalForSales(sales);
      final avg = total / sales.length;
      final pay = SalesHistoryService.to.getPaymentMethodTotals(sales);
      final hourly = SalesHistoryService.to.getHourlyTotals(d);
      final top = SalesHistoryService.to.getTopItems(sales, top: 15);
      final staff = SalesHistoryService.to.getStaffTotals(sales);
      final tables = SalesHistoryService.to.getTableTotals(sales);

      _writeTitle(summary, 'Günlük Rapor', _dateFmt.format(d));
      _writeKpis(summary, total, sales.length, avg);

      final charts = ChartCollection(summary);
      var row = 7;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Ödeme tipleri',
        entries: pay.entries
            .map((e) => MapEntry(
                  SettingsService.to.paymentMethodLabel(e.key),
                  e.value,
                ))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
        chartType: ExcelChartType.pie,
        chartTitle: 'Ödeme dağılımı',
      );

      row += 2;
      var hourlyEntries = List.generate(24, (h) {
        final v = hourly[h] ?? 0.0;
        return MapEntry('$h:00', v);
      }).where((e) => e.value > 0).toList();
      if (hourlyEntries.isEmpty) {
        hourlyEntries = List.generate(
          24,
          (h) => MapEntry('$h:00', hourly[h] ?? 0.0),
        );
      }
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Saatlik ciro',
        entries: hourlyEntries,
        chartType: ExcelChartType.line,
        chartTitle: 'Saatlik satış',
        chartBeside: true,
      );

      row += 2;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Personel',
        entries: staff,
        chartType: ExcelChartType.column,
        chartTitle: 'Personel satışları',
      );

      row += 2;
      _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Masalar',
        entries: tables,
        chartType: ExcelChartType.column,
        chartTitle: 'Masa satışları',
      );
      summary.charts = charts;

      _writeSalesSheet(detail, sales);
      _writeProductSheet(products, top);

      final bytes = workbook.saveAsStream();
      workbook.dispose();
      await _share(
        bytes,
        'orderix_gunluk_${_fileStamp.format(DateTime.now())}.xlsx',
        shareOrigin: shareOrigin,
      );
    } catch (e) {
      if (kDebugMode) print('[ReportExcel] daily: $e');
      AppToast.error('Excel oluşturulamadı', title: 'Hata');
    }
  }

  static Future<void> exportMonthly(
    int year,
    int month, {
    Rect? shareOrigin,
  }) async {
    final sales = SalesHistoryService.to.getSalesForMonth(year, month);
    if (sales.isEmpty) {
      AppToast.warning('Bu ay için satış yok', title: 'Excel');
      return;
    }

    try {
      final workbook = Workbook(0);
      final summary = workbook.worksheets.addWithName('Özet');
      final daysSheet = workbook.worksheets.addWithName('Günler');
      final detail = workbook.worksheets.addWithName('Satışlar');
      final products = workbook.worksheets.addWithName('Ürünler');

      final total = SalesHistoryService.to.getTotalForSales(sales);
      final avg = total / sales.length;
      final pay = SalesHistoryService.to.getPaymentMethodTotals(sales);
      final daily = SalesHistoryService.to.getDailyTotals(year, month);
      final daySummaries = SalesHistoryService.to.getDailySummaries(year, month);
      final top = SalesHistoryService.to.getTopItems(sales, top: 15);
      final staff = SalesHistoryService.to.getStaffTotals(sales);
      final tables = SalesHistoryService.to.getTableTotals(sales);
      final label = DateFormat('MMMM yyyy', 'tr').format(DateTime(year, month));

      _writeTitle(summary, 'Aylık Rapor', label);
      _writeKpis(summary, total, sales.length, avg);

      final charts = ChartCollection(summary);
      var row = 7;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Ödeme tipleri',
        entries: pay.entries
            .map((e) => MapEntry(
                  SettingsService.to.paymentMethodLabel(e.key),
                  e.value,
                ))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
        chartType: ExcelChartType.pie,
        chartTitle: 'Ödeme dağılımı',
      );

      row += 2;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final dayEntries = List.generate(daysInMonth, (i) {
        final day = i + 1;
        return MapEntry('$day', daily[day] ?? 0.0);
      });
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Günlük ciro',
        entries: dayEntries,
        chartType: ExcelChartType.column,
        chartTitle: 'Günlük satışlar',
        chartBeside: true,
      );

      row += 2;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Personel',
        entries: staff,
        chartType: ExcelChartType.column,
        chartTitle: 'Personel satışları',
      );

      row += 2;
      _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Masalar',
        entries: tables,
        chartType: ExcelChartType.column,
        chartTitle: 'Masa satışları',
      );
      summary.charts = charts;

      _writeDaySummariesSheet(daysSheet, daySummaries);
      _writeSalesSheet(detail, sales);
      _writeProductSheet(products, top);

      final bytes = workbook.saveAsStream();
      workbook.dispose();
      await _share(
        bytes,
        'orderix_aylik_${year}_${month.toString().padLeft(2, '0')}.xlsx',
        shareOrigin: shareOrigin,
      );
    } catch (e) {
      if (kDebugMode) print('[ReportExcel] monthly: $e');
      AppToast.error('Excel oluşturulamadı', title: 'Hata');
    }
  }

  static Future<void> exportYearly(
    int year, {
    Rect? shareOrigin,
  }) async {
    final sales = SalesHistoryService.to.getSalesForYear(year);
    if (sales.isEmpty) {
      AppToast.warning('Bu yıl için satış yok', title: 'Excel');
      return;
    }

    try {
      final workbook = Workbook(0);
      final summary = workbook.worksheets.addWithName('Özet');
      final monthsSheet = workbook.worksheets.addWithName('Aylar');
      final products = workbook.worksheets.addWithName('Ürünler');

      final total = SalesHistoryService.to.getTotalForSales(sales);
      final avg = total / sales.length;
      final pay = SalesHistoryService.to.getPaymentMethodTotals(sales);
      final monthly = SalesHistoryService.to.getMonthlyTotals(year);
      final top = SalesHistoryService.to.getTopItems(sales, top: 15);
      final staff = SalesHistoryService.to.getStaffTotals(sales);
      final tables = SalesHistoryService.to.getTableTotals(sales);
      const monthNames = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];

      _writeTitle(summary, 'Yıllık Rapor', '$year');
      _writeKpis(summary, total, sales.length, avg);

      final charts = ChartCollection(summary);
      var row = 7;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Ödeme tipleri',
        entries: pay.entries
            .map((e) => MapEntry(
                  SettingsService.to.paymentMethodLabel(e.key),
                  e.value,
                ))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
        chartType: ExcelChartType.pie,
        chartTitle: 'Ödeme dağılımı',
      );

      row += 2;
      final monthEntries = List.generate(12, (i) {
        final m = i + 1;
        return MapEntry(monthNames[i], monthly[m] ?? 0.0);
      });
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Aylık ciro',
        entries: monthEntries,
        chartType: ExcelChartType.line,
        chartTitle: 'Aylık satış trendi',
        chartBeside: true,
      );

      row += 2;
      row = _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Personel',
        entries: staff,
        chartType: ExcelChartType.column,
        chartTitle: 'Personel satışları',
      );

      row += 2;
      _writeNamedTotals(
        summary,
        charts: charts,
        startRow: row,
        title: 'Masalar',
        entries: tables,
        chartType: ExcelChartType.column,
        chartTitle: 'Masa satışları',
      );
      summary.charts = charts;

      // Months detail sheet
      monthsSheet.getRangeByName('A1').setText('Ay');
      monthsSheet.getRangeByName('B1').setText('Ciro');
      monthsSheet.getRangeByName('C1').setText('Adisyon');
      monthsSheet.getRangeByName('A1:C1').cellStyle.bold = true;
      for (var m = 1; m <= 12; m++) {
        final ms = SalesHistoryService.to.getSalesForMonth(year, m);
        monthsSheet.getRangeByIndex(m + 1, 1).setText(monthNames[m - 1]);
        monthsSheet
            .getRangeByIndex(m + 1, 2)
            .setNumber(monthly[m] ?? 0.0);
        monthsSheet.getRangeByIndex(m + 1, 3).setNumber(ms.length.toDouble());
      }
      monthsSheet.getRangeByName('B2:B13').numberFormat = '#,##0.00';
      monthsSheet.autoFitColumn(1);
      monthsSheet.autoFitColumn(2);
      monthsSheet.autoFitColumn(3);

      _writeProductSheet(products, top);

      final bytes = workbook.saveAsStream();
      workbook.dispose();
      await _share(bytes, 'orderix_yillik_$year.xlsx',
          shareOrigin: shareOrigin);
    } catch (e) {
      if (kDebugMode) print('[ReportExcel] yearly: $e');
      AppToast.error('Excel oluşturulamadı', title: 'Hata');
    }
  }

  // ── Sheet helpers ────────────────────────────────────────────

  static void _writeTitle(Worksheet sheet, String title, String subtitle) {
    sheet.getRangeByName('A1').setText(title);
    sheet.getRangeByName('A1').cellStyle.bold = true;
    sheet.getRangeByName('A1').cellStyle.fontSize = 16;
    sheet.getRangeByName('A2').setText(subtitle);
    sheet.getRangeByName('A2').cellStyle.fontSize = 12;
    sheet.getRangeByName('A1').columnWidth = 22;
    sheet.getRangeByName('B1').columnWidth = 14;
  }

  static void _writeKpis(
    Worksheet sheet,
    double total,
    int count,
    double avg,
  ) {
    sheet.getRangeByName('A4').setText('Toplam ciro');
    sheet.getRangeByName('B4').setNumber(total);
    sheet.getRangeByName('A5').setText('Adisyon sayısı');
    sheet.getRangeByName('B5').setNumber(count.toDouble());
    sheet.getRangeByName('A6').setText('Ortalama adisyon');
    sheet.getRangeByName('B6').setNumber(avg);
    sheet.getRangeByName('A4:A6').cellStyle.bold = true;
    sheet.getRangeByName('B4').numberFormat = '#,##0.00';
    sheet.getRangeByName('B6').numberFormat = '#,##0.00';
  }

  /// Writes a labeled block of name/value rows and attaches a chart.
  /// Returns the next free row index after the block.
  static int _writeNamedTotals(
    Worksheet sheet, {
    required ChartCollection charts,
    required int startRow,
    required String title,
    required List<MapEntry<String, double>> entries,
    required ExcelChartType chartType,
    required String chartTitle,
    bool chartBeside = false,
  }) {
    if (entries.isEmpty) return startRow;

    sheet.getRangeByIndex(startRow, 1).setText(title);
    sheet.getRangeByIndex(startRow, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(startRow, 1).cellStyle.fontSize = 13;

    final headerRow = startRow + 1;
    sheet.getRangeByIndex(headerRow, 1).setText('Kalem');
    sheet.getRangeByIndex(headerRow, 2).setText('Tutar');
    sheet.getRangeByIndex(headerRow, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(headerRow, 2).cellStyle.bold = true;

    for (var i = 0; i < entries.length; i++) {
      final r = headerRow + 1 + i;
      sheet.getRangeByIndex(r, 1).setText(entries[i].key);
      sheet.getRangeByIndex(r, 2).setNumber(entries[i].value);
    }
    final dataStart = headerRow;
    final dataEnd = headerRow + entries.length;
    sheet.getRangeByIndex(dataStart + 1, 2, dataEnd, 2).numberFormat =
        '#,##0.00';

    final chart = charts.add();
    chart.chartType = chartType;
    chart.dataRange = sheet.getRangeByIndex(dataStart, 1, dataEnd, 2);
    chart.isSeriesInRows = false;
    chart.chartTitle = chartTitle;
    chart.chartTitleArea.bold = true;
    chart.chartTitleArea.size = 12;
    if (chartBeside) {
      chart.topRow = startRow;
      chart.bottomRow = startRow + 12;
      chart.leftColumn = 4;
      chart.rightColumn = 10;
    } else {
      chart.topRow = dataEnd + 1;
      chart.bottomRow = dataEnd + 12;
      chart.leftColumn = 1;
      chart.rightColumn = 6;
    }

    if (chartBeside) {
      return (dataEnd + 2) < (startRow + 14) ? startRow + 14 : dataEnd + 2;
    }
    return dataEnd + 14;
  }

  static void _writeSalesSheet(
    Worksheet sheet,
    List<Map<String, dynamic>> sales,
  ) {
    sheet.getRangeByName('A1').setText('Saat');
    sheet.getRangeByName('B1').setText('Masa');
    sheet.getRangeByName('C1').setText('Personel');
    sheet.getRangeByName('D1').setText('Ödeme');
    sheet.getRangeByName('E1').setText('Tutar');
    sheet.getRangeByName('F1').setText('Ürünler');
    sheet.getRangeByName('A1:F1').cellStyle.bold = true;

    for (var i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final r = i + 2;
      final date = DateTime.parse(sale['date'] as String);
      final items = (sale['items'] as List).cast<Map<String, dynamic>>();
      final itemsText = items
          .map((it) =>
              '${(it['quantity'] as num).toInt()}×${it['name']}')
          .join(', ');
      sheet.getRangeByIndex(r, 1).setText(_timeFmt.format(date));
      sheet
          .getRangeByIndex(r, 2)
          .setText(sale['tableName'] as String? ?? '—');
      sheet.getRangeByIndex(r, 3).setText(
            SalesHistoryService.staffLabel(sale['staffEmail'] as String?),
          );
      sheet.getRangeByIndex(r, 4).setText(
            SettingsService.to.paymentMethodLabel(
              (sale['paymentMethod'] as String?) ?? 'cash',
            ),
          );
      sheet
          .getRangeByIndex(r, 5)
          .setNumber((sale['total'] as num).toDouble());
      sheet.getRangeByIndex(r, 6).setText(itemsText);
    }
    if (sales.isNotEmpty) {
      sheet.getRangeByIndex(2, 5, sales.length + 1, 5).numberFormat =
          '#,##0.00';
    }
    for (var c = 1; c <= 6; c++) {
      sheet.autoFitColumn(c);
    }
  }

  static void _writeProductSheet(
    Worksheet sheet,
    List<MapEntry<String, double>> top,
  ) {
    sheet.getRangeByName('A1').setText('Ürün');
    sheet.getRangeByName('B1').setText('Adet');
    sheet.getRangeByName('A1:B1').cellStyle.bold = true;
    for (var i = 0; i < top.length; i++) {
      sheet.getRangeByIndex(i + 2, 1).setText(top[i].key);
      sheet.getRangeByIndex(i + 2, 2).setNumber(top[i].value);
    }
    if (top.isNotEmpty) {
      final charts = ChartCollection(sheet);
      final chart = charts.add();
      chart.chartType = ExcelChartType.bar;
      chart.dataRange = sheet.getRangeByIndex(1, 1, top.length + 1, 2);
      chart.isSeriesInRows = false;
      chart.chartTitle = 'En çok satanlar';
      chart.topRow = 1;
      chart.bottomRow = 14;
      chart.leftColumn = 4;
      chart.rightColumn = 10;
      sheet.charts = charts;
    }
    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);
  }

  static void _writeDaySummariesSheet(
    Worksheet sheet,
    List<Map<String, dynamic>> days,
  ) {
    sheet.getRangeByName('A1').setText('Tarih');
    sheet.getRangeByName('B1').setText('Ciro');
    sheet.getRangeByName('C1').setText('Adisyon');
    sheet.getRangeByName('D1').setText('Ortalama');
    sheet.getRangeByName('A1:D1').cellStyle.bold = true;
    for (var i = 0; i < days.length; i++) {
      final r = i + 2;
      final date = days[i]['date'] as DateTime;
      final total = days[i]['total'] as double;
      final count = days[i]['count'] as int;
      sheet.getRangeByIndex(r, 1).setText(_dateFmt.format(date));
      sheet.getRangeByIndex(r, 2).setNumber(total);
      sheet.getRangeByIndex(r, 3).setNumber(count.toDouble());
      sheet
          .getRangeByIndex(r, 4)
          .setNumber(count == 0 ? 0 : total / count);
    }
    if (days.isNotEmpty) {
      sheet.getRangeByIndex(2, 2, days.length + 1, 2).numberFormat =
          '#,##0.00';
      sheet.getRangeByIndex(2, 4, days.length + 1, 4).numberFormat =
          '#,##0.00';
    }
    for (var c = 1; c <= 4; c++) {
      sheet.autoFitColumn(c);
    }
  }

  /// Anchor rect for iPad/iOS share sheet popover (required by UIActivityViewController).
  static Rect? shareOriginFrom(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return null;
    return topLeft & size;
  }

  static Future<void> _share(
    List<int> bytes,
    String fileName, {
    Rect? shareOrigin,
  }) async {
    // iPad requires a non-zero popover source rect inside the window.
    final origin = shareOrigin ?? const Rect.fromLTWH(120, 120, 40, 40);
    const mime =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    // fromData works on web + mobile without dart:io.
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: mime,
            name: fileName,
          ),
        ],
        sharePositionOrigin: origin,
      ),
    );
    AppToast.success('Excel hazır', title: 'Dışa aktarım');
  }
}
