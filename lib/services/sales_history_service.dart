import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SalesHistoryService extends GetxService {
  static SalesHistoryService get to => Get.find();

  final RxList<Map<String, dynamic>> sales = <Map<String, dynamic>>[].obs;
  late String _filePath;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/sales_history.json';
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final str = prefs.getString('sales_history');
        if (str != null) {
          final list = json.decode(str) as List;
          sales.assignAll(list.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            map['items'] = List<Map<String, dynamic>>.from(
              (map['items'] as List).map((i) => Map<String, dynamic>.from(i as Map)),
            );
            return map;
          }));
        }
      } else {
        final file = File(_filePath);
        if (await file.exists()) {
          final str = await file.readAsString();
          final list = json.decode(str) as List;
          sales.assignAll(list.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            map['items'] = List<Map<String, dynamic>>.from(
              (map['items'] as List).map((i) => Map<String, dynamic>.from(i as Map)),
            );
            return map;
          }));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading sales history: $e');
    }
  }

  Future<void> _save() async {
    try {
      final str = json.encode(sales);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sales_history', str);
      } else {
        final file = File(_filePath);
        await file.writeAsString(str);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving sales history: $e');
    }
  }

  void recordSale({
    required String tableName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
  }) {
    sales.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'tableName': tableName,
      'items': List<Map<String, dynamic>>.from(items),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'date': DateTime.now().toIso8601String(),
    });
    _save();
  }

  List<Map<String, dynamic>> getSalesForDate(DateTime date) {
    return sales.where((sale) {
      final d = DateTime.parse(sale['date'] as String);
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  List<Map<String, dynamic>> getSalesForMonth(int year, int month) {
    return sales.where((sale) {
      final d = DateTime.parse(sale['date'] as String);
      return d.year == year && d.month == month;
    }).toList();
  }

  List<Map<String, dynamic>> getSalesForYear(int year) {
    return sales.where((sale) {
      final d = DateTime.parse(sale['date'] as String);
      return d.year == year;
    }).toList();
  }

  double getTotalForSales(List<Map<String, dynamic>> salesList) {
    return salesList.fold(0.0, (sum, s) => sum + (s['total'] as double));
  }

  // Returns map of hour -> total for a given date
  Map<int, double> getHourlyTotals(DateTime date) {
    final result = <int, double>{};
    for (final sale in getSalesForDate(date)) {
      final hour = DateTime.parse(sale['date'] as String).hour;
      result[hour] = (result[hour] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  // Returns map of day -> total for a given month
  Map<int, double> getDailyTotals(int year, int month) {
    final result = <int, double>{};
    for (final sale in getSalesForMonth(year, month)) {
      final day = DateTime.parse(sale['date'] as String).day;
      result[day] = (result[day] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  // Returns map of month -> total for a given year
  Map<int, double> getMonthlyTotals(int year) {
    final result = <int, double>{for (int m = 1; m <= 12; m++) m: 0.0};
    for (final sale in getSalesForYear(year)) {
      final month = DateTime.parse(sale['date'] as String).month;
      result[month] = (result[month] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  // Returns top N items by quantity sold from a list of sales
  List<MapEntry<String, double>> getTopItems(
    List<Map<String, dynamic>> salesList, {
    int top = 5,
  }) {
    final counts = <String, double>{};
    for (final sale in salesList) {
      for (final item in (sale['items'] as List)) {
        final name = (item as Map)['name'] as String;
        final qty = (item['quantity'] as num).toDouble();
        counts[name] = (counts[name] ?? 0.0) + qty;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(top).toList();
  }

  // Get recent sales (for notifications), most recent first
  List<Map<String, dynamic>> getRecentSales({int limit = 30}) {
    final sorted = List<Map<String, dynamic>>.from(sales)
      ..sort((a, b) {
        final da = DateTime.parse(a['date'] as String);
        final db = DateTime.parse(b['date'] as String);
        return db.compareTo(da);
      });
    return sorted.take(limit).toList();
  }
}
