import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/kitchen_service.dart';
import 'package:adisyos/services/inventory_service.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';

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
            final Map<String, dynamic> table =
                Map<String, dynamic>.from(item as Map);
            table['orders'] = List<Map<String, dynamic>>.from(
              (table['orders'] as List)
                  .map((order) => Map<String, dynamic>.from(order as Map)),
            );
            table['staffEmail'] ??= '';
            return table;
          }));
        }
      } else {
        final file = File(_tablesFilePath);
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final List<dynamic> jsonList = json.decode(jsonString);
          tables.assignAll(jsonList.map((item) {
            final Map<String, dynamic> table =
                Map<String, dynamic>.from(item as Map);
            table['orders'] = List<Map<String, dynamic>>.from(
              (table['orders'] as List)
                  .map((order) => Map<String, dynamic>.from(order as Map)),
            );
            table['staffEmail'] ??= '';
            return table;
          }));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading tables: $e');
      }
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
      if (kDebugMode) {
        print('Error saving tables: $e');
      }
    }
  }

  void addTable(String name) {
    tables.add({
      'name': name,
      'isOccupied': false,
      'orders': <Map<String, dynamic>>[],
      'total': 0.0,
      'discount': 0.0,
      'staffEmail': '',
    });
    _saveTables();
  }

  void removeTable(int index) {
    KitchenService.to.removeTicketsForTable(index);
    tables.removeAt(index);
    _saveTables();
  }

  void updateTableName(int index, String newName) {
    tables[index]['name'] = newName;
    tables.refresh();
    _saveTables();
  }

  void toggleTableStatus(int index) {
    tables[index]['isOccupied'] = !tables[index]['isOccupied'];
    tables.refresh();
    _saveTables();
  }

  void _updateTableStatus(int tableIndex) {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    tables[tableIndex]['isOccupied'] = orders.isNotEmpty;
    tables.refresh();
    _saveTables();
  }

  void addOrder(int tableIndex, String name, double price) {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    final existingOrderIndex =
        orders.indexWhere((order) => order['name'] == name);

    if (existingOrderIndex != -1) {
      orders[existingOrderIndex]['quantity'] =
          (orders[existingOrderIndex]['quantity'] as int) + 1;
    } else {
      orders.add({
        'name': name,
        'quantity': 1,
        'price': price,
      });
    }

    tables[tableIndex]['total'] =
        (tables[tableIndex]['total'] as double) + price;

    // Assign staff to table on first order
    if ((tables[tableIndex]['staffEmail'] as String? ?? '').isEmpty) {
      try {
        final email = AuthController.to.user.value?.email ?? '';
        if (email.isNotEmpty) tables[tableIndex]['staffEmail'] = email;
      } catch (_) {}
    }

    // Update kitchen ticket
    final newQty = existingOrderIndex != -1
        ? orders[existingOrderIndex]['quantity'] as int
        : 1;
    KitchenService.to.addOrUpdateTicket(
      tableIndex: tableIndex,
      tableName: tables[tableIndex]['name'] as String,
      itemName: name,
      quantity: newQty,
    );

    _updateTableStatus(tableIndex);
  }

  void removeOrder(int tableIndex, int orderIndex) {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    if (orderIndex >= orders.length) return;
    final order = orders[orderIndex];
    final price = order['price'] as double;
    final quantity = order['quantity'] as int;
    final name = order['name'] as String;

    final currentTotal = tables[tableIndex]['total'] as double;
    tables[tableIndex]['total'] = (currentTotal - (price * quantity))
        .clamp(0.0, double.infinity);

    // If discount exceeds new total, reset discount
    final newTotal = tables[tableIndex]['total'] as double;
    final discount = (tables[tableIndex]['discount'] ?? 0.0) as double;
    if (discount > newTotal) {
      tables[tableIndex]['discount'] = 0.0;
    }

    KitchenService.to.removeTicketForItem(tableIndex, name);
    orders.removeAt(orderIndex);
    _updateTableStatus(tableIndex);
  }

  void decrementOrder(int tableIndex, int orderIndex) {
    final orders = tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
    if (orderIndex >= orders.length) return;
    final order = orders[orderIndex];
    final price = order['price'] as double;
    final quantity = order['quantity'] as int;
    final name = order['name'] as String;

    if (quantity <= 1) {
      KitchenService.to.removeTicketForItem(tableIndex, name);
      removeOrder(tableIndex, orderIndex);
      return;
    }

    orders[orderIndex]['quantity'] = quantity - 1;
    tables[tableIndex]['total'] =
        ((tables[tableIndex]['total'] as double) - price)
            .clamp(0.0, double.infinity);

    KitchenService.to.addOrUpdateTicket(
      tableIndex: tableIndex,
      tableName: tables[tableIndex]['name'] as String,
      itemName: name,
      quantity: quantity - 1,
    );

    _updateTableStatus(tableIndex);
  }

  List<Map<String, dynamic>> getOrders(int tableIndex) {
    return tables[tableIndex]['orders'] as List<Map<String, dynamic>>;
  }

  double getTotal(int tableIndex) {
    return tables[tableIndex]['total'] as double;
  }

  void clearTable(int tableIndex) {
    KitchenService.to.removeTicketsForTable(tableIndex);
    tables[tableIndex]['orders'] = <Map<String, dynamic>>[];
    tables[tableIndex]['total'] = 0.0;
    tables[tableIndex]['isOccupied'] = false;
    tables[tableIndex]['discount'] = 0.0;
    tables[tableIndex]['staffEmail'] = '';
    tables.refresh();
    _saveTables();
  }

  // Record payment and clear the table
  void recordPayment(int tableIndex, {String paymentMethod = 'cash'}) {
    final table = tables[tableIndex];
    final orders = List<Map<String, dynamic>>.from(
      table['orders'] as List<Map<String, dynamic>>,
    );
    final subtotal = table['total'] as double;
    final discount = (table['discount'] ?? 0.0) as double;
    final total = (subtotal - discount).clamp(0.0, double.infinity);
    final staffEmail = (table['staffEmail'] as String? ?? '');

    SalesHistoryService.to.recordSale(
      tableName: table['name'] as String,
      items: orders,
      subtotal: subtotal,
      discount: discount,
      total: total,
      staffEmail: staffEmail,
      paymentMethod: paymentMethod,
    );

    InventoryService.to.decrementForSale(orders);

    clearTable(tableIndex);
  }

  void applyDiscount(int tableIndex, double discountPercentage) {
    final currentTotal = tables[tableIndex]['total'] as double;
    final clamped = discountPercentage.clamp(0.0, 100.0);
    final discountAmount = currentTotal * (clamped / 100);
    tables[tableIndex]['discount'] = discountAmount;
    tables.refresh();
    _saveTables();
  }

  double getTotalWithDiscount(int tableIndex) {
    final total = tables[tableIndex]['total'] as double;
    final discount = (tables[tableIndex]['discount'] ?? 0.0) as double;
    return (total - discount).clamp(0.0, double.infinity);
  }

  double getDiscount(int tableIndex) {
    return (tables[tableIndex]['discount'] ?? 0.0) as double;
  }

  // Move a single order item to another table
  void moveOrderToTable(int fromTableIndex, int toTableIndex, int orderIndex) {
    final srcOrders = getOrders(fromTableIndex);
    if (orderIndex >= srcOrders.length) return;

    final order = srcOrders[orderIndex];
    final name = order['name'] as String;
    final price = order['price'] as double;
    final quantity = order['quantity'] as int;

    final destOrders = getOrders(toTableIndex);
    final existingIdx = destOrders.indexWhere((o) => o['name'] == name);
    if (existingIdx != -1) {
      destOrders[existingIdx]['quantity'] =
          (destOrders[existingIdx]['quantity'] as int) + quantity;
    } else {
      destOrders.add({'name': name, 'quantity': quantity, 'price': price});
    }

    tables[toTableIndex]['total'] =
        (tables[toTableIndex]['total'] as double) + (price * quantity);
    tables[toTableIndex]['isOccupied'] = true;

    tables[fromTableIndex]['total'] =
        ((tables[fromTableIndex]['total'] as double) - (price * quantity))
            .clamp(0.0, double.infinity);
    srcOrders.removeAt(orderIndex);
    tables[fromTableIndex]['isOccupied'] = srcOrders.isNotEmpty;

    final newSrcTotal = tables[fromTableIndex]['total'] as double;
    final srcDiscount = (tables[fromTableIndex]['discount'] ?? 0.0) as double;
    if (srcDiscount > newSrcTotal) {
      tables[fromTableIndex]['discount'] = 0.0;
    }

    // Sync kitchen tickets
    KitchenService.to.removeTicketForItem(fromTableIndex, name);
    KitchenService.to.addOrUpdateTicket(
      tableIndex: toTableIndex,
      tableName: tables[toTableIndex]['name'] as String,
      itemName: name,
      quantity: existingIdx != -1
          ? destOrders[existingIdx]['quantity'] as int
          : quantity,
    );

    tables.refresh();
    _saveTables();
  }

  // Move all orders from one table to another
  void moveAllOrdersToTable(int fromTableIndex, int toTableIndex) {
    final srcOrders =
        List<Map<String, dynamic>>.from(getOrders(fromTableIndex));
    final destOrders = getOrders(toTableIndex);
    double addedTotal = 0.0;

    for (final order in srcOrders) {
      final name = order['name'] as String;
      final price = order['price'] as double;
      final quantity = order['quantity'] as int;
      addedTotal += price * quantity;

      final existingIdx = destOrders.indexWhere((o) => o['name'] == name);
      if (existingIdx != -1) {
        destOrders[existingIdx]['quantity'] =
            (destOrders[existingIdx]['quantity'] as int) + quantity;
      } else {
        destOrders.add({'name': name, 'quantity': quantity, 'price': price});
      }

      KitchenService.to.removeTicketForItem(fromTableIndex, name);
      final destQty = existingIdx != -1
          ? destOrders[existingIdx]['quantity'] as int
          : quantity;
      KitchenService.to.addOrUpdateTicket(
        tableIndex: toTableIndex,
        tableName: tables[toTableIndex]['name'] as String,
        itemName: name,
        quantity: destQty,
      );
    }

    tables[toTableIndex]['total'] =
        (tables[toTableIndex]['total'] as double) + addedTotal;
    tables[toTableIndex]['isOccupied'] = destOrders.isNotEmpty;

    tables[fromTableIndex]['orders'] = <Map<String, dynamic>>[];
    tables[fromTableIndex]['total'] = 0.0;
    tables[fromTableIndex]['discount'] = 0.0;
    tables[fromTableIndex]['isOccupied'] = false;
    tables[fromTableIndex]['staffEmail'] = '';

    tables.refresh();
    _saveTables();
  }
}
