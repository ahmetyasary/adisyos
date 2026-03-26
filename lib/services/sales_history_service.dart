import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesHistoryService extends GetxService {
  static SalesHistoryService get to => Get.find();

  final RxList<Map<String, dynamic>> sales = <Map<String, dynamic>>[].obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _load();
    });
    _load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('sales_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sale_items',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Load ────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      // Load all sales with their line-items, newest first.
      // For very high-volume production use, consider paginating by date range.
      final rows = await _db
          .from('sales')
          .select('*, sale_items(*)')
          .order('created_at', ascending: false);

      sales.assignAll(rows.map(_rowToSale).toList());
    } catch (e) {
      if (kDebugMode) print('[SalesHistoryService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToSale(Map<String, dynamic> row) => {
        'id': row['id'] as String,
        'tableName': row['table_name'] as String,
        'items': (row['sale_items'] as List)
            .map((i) => {
                  'name': i['name'] as String,
                  'quantity': i['quantity'] as int,
                  'price': (i['price'] as num).toDouble(),
                })
            .toList(),
        'subtotal': (row['subtotal'] as num).toDouble(),
        'discount': (row['discount'] as num).toDouble(),
        'total': (row['total'] as num).toDouble(),
        'date': row['created_at'] as String,
        'staffEmail': row['staff_email'] as String,
        'paymentMethod': row['payment_method'] as String,
      };

  // ── Record a completed sale ──────────────────────────────────

  Future<void> recordSale({
    required String tableName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    String staffEmail = '',
    String paymentMethod = 'cash',
  }) async {
    try {
      // Insert sale header
      final saleRow = await _db
          .from('sales')
          .insert({
            'table_name': tableName,
            'subtotal': subtotal,
            'discount': discount,
            'total': total,
            'payment_method': paymentMethod,
            'staff_email': staffEmail,
          })
          .select()
          .single();

      final saleId = saleRow['id'] as String;

      // Insert line items
      if (items.isNotEmpty) {
        await _db.from('sale_items').insert(
          items
              .map((item) => {
                    'sale_id': saleId,
                    'name': item['name'] as String,
                    'quantity': item['quantity'] as int,
                    'price': (item['price'] as num).toDouble(),
                  })
              .toList(),
        );
      }

      // Prepend to local cache
      sales.insert(0, {
        'id': saleId,
        'tableName': tableName,
        'items': List<Map<String, dynamic>>.from(items),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'date': saleRow['created_at'] as String,
        'staffEmail': staffEmail,
        'paymentMethod': paymentMethod,
      });
    } catch (e) {
      if (kDebugMode) print('[SalesHistoryService] recordSale error: $e');
    }
  }

  // ── Date-filtered queries (operate on in-memory cache) ───────

  List<Map<String, dynamic>> getSalesForDate(DateTime date) {
    return sales.where((s) {
      final d = DateTime.parse(s['date'] as String);
      return d.year == date.year &&
          d.month == date.month &&
          d.day == date.day;
    }).toList();
  }

  List<Map<String, dynamic>> getSalesForMonth(int year, int month) {
    return sales.where((s) {
      final d = DateTime.parse(s['date'] as String);
      return d.year == year && d.month == month;
    }).toList();
  }

  List<Map<String, dynamic>> getSalesForYear(int year) {
    return sales.where((s) {
      final d = DateTime.parse(s['date'] as String);
      return d.year == year;
    }).toList();
  }

  // ── Aggregations ─────────────────────────────────────────────

  double getTotalForSales(List<Map<String, dynamic>> salesList) =>
      salesList.fold(0.0, (sum, s) => sum + (s['total'] as double));

  Map<String, double> getPaymentMethodTotals(
    List<Map<String, dynamic>> salesList,
  ) {
    final result = <String, double>{};
    for (final sale in salesList) {
      final method = (sale['paymentMethod'] as String?) ?? 'cash';
      result[method] = (result[method] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  Map<int, double> getHourlyTotals(DateTime date) {
    final result = <int, double>{};
    for (final sale in getSalesForDate(date)) {
      final hour = DateTime.parse(sale['date'] as String).hour;
      result[hour] = (result[hour] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  Map<int, double> getDailyTotals(int year, int month) {
    final result = <int, double>{};
    for (final sale in getSalesForMonth(year, month)) {
      final day = DateTime.parse(sale['date'] as String).day;
      result[day] = (result[day] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

  Map<int, double> getMonthlyTotals(int year) {
    final result = <int, double>{for (int m = 1; m <= 12; m++) m: 0.0};
    for (final sale in getSalesForYear(year)) {
      final month = DateTime.parse(sale['date'] as String).month;
      result[month] = (result[month] ?? 0.0) + (sale['total'] as double);
    }
    return result;
  }

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
    return (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(top)
        .toList();
  }

  List<Map<String, dynamic>> getRecentSales({int limit = 30}) =>
      sales.take(limit).toList(); // already sorted newest-first from _load
}
