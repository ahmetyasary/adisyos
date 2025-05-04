import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class TableService extends GetxService {
  static TableService get to => Get.find();

  final RxList<Map<String, dynamic>> tables = <Map<String, dynamic>>[].obs;
  late final String _tablesFilePath;

  @override
  void onInit() {
    super.onInit();
    _initTablesFile();
  }

  Future<void> _initTablesFile() async {
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      _tablesFilePath = '${directory.path}/tables.json';
    }
    await _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('tables');
        if (jsonString != null) {
          final List<dynamic> jsonList = json.decode(jsonString);
          tables.assignAll(jsonList.map((item) {
            final Map<String, dynamic> table = Map<String, dynamic>.from(item);
            table['orders'] = List<Map<String, dynamic>>.from(
              (table['orders'] as List)
                  .map((order) => Map<String, dynamic>.from(order)),
            );
            return table;
          }));
        }
      } else {
        final file = File(_tablesFilePath);
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final List<dynamic> jsonList = json.decode(jsonString);
          tables.assignAll(jsonList.map((item) {
            final Map<String, dynamic> table = Map<String, dynamic>.from(item);
            table['orders'] = List<Map<String, dynamic>>.from(
              (table['orders'] as List)
                  .map((order) => Map<String, dynamic>.from(order)),
            );
            return table;
          }));
        }
      }
    } catch (e) {
      print('Error loading tables: $e');
    }
  }

  Future<void> _saveTables() async {
    try {
      final jsonString = json.encode(tables);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tables', jsonString);
      } else {
        final file = File(_tablesFilePath);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving tables: $e');
    }
  }

  void addTable(String name) {
    tables.add({
      'name': name,
      'isOccupied': false,
      'orders': <Map<String, dynamic>>[],
      'total': 0.0,
    });
    _saveTables();
  }

  void removeTable(int index) {
    tables.removeAt(index);
    _saveTables();
  }

  void toggleTableStatus(int index) {
    tables[index]['isOccupied'] = !tables[index]['isOccupied'];
    tables.refresh();
    _saveTables();
  }

  void _updateTableStatus(int tableIndex) {
    final orders = (tables[tableIndex]['orders'] as List<Map<String, dynamic>>);
    tables[tableIndex]['isOccupied'] = orders.isNotEmpty;
    tables.refresh();
    _saveTables();
  }

  void addOrder(int tableIndex, String name, double price) {
    final orders = (tables[tableIndex]['orders'] as List<Map<String, dynamic>>);
    final existingOrderIndex =
        orders.indexWhere((order) => order['name'] == name);

    if (existingOrderIndex != -1) {
      orders[existingOrderIndex]['quantity']++;
    } else {
      orders.add({
        'name': name,
        'quantity': 1,
        'price': price,
      });
    }

    tables[tableIndex]['total'] =
        (tables[tableIndex]['total'] as double) + price;
    _updateTableStatus(tableIndex);
  }

  void removeOrder(int tableIndex, int orderIndex) {
    final orders = (tables[tableIndex]['orders'] as List<Map<String, dynamic>>);
    final order = orders[orderIndex];
    final price = order['price'] as double;
    final quantity = order['quantity'] as int;

    tables[tableIndex]['total'] =
        (tables[tableIndex]['total'] as double) - (price * quantity);
    orders.removeAt(orderIndex);
    _updateTableStatus(tableIndex);
  }

  List<Map<String, dynamic>> getOrders(int tableIndex) {
    return (tables[tableIndex]['orders'] as List<Map<String, dynamic>>);
  }

  double getTotal(int tableIndex) {
    return tables[tableIndex]['total'] as double;
  }
}
