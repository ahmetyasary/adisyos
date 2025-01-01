import 'package:get/get.dart';

class TableService extends GetxService {
  static TableService get to => Get.find();

  final RxList<Map<String, dynamic>> tables = <Map<String, dynamic>>[].obs;

  void addTable(String name) {
    tables.add({
      'name': name,
      'isOccupied': false,
      'orders': <Map<String, dynamic>>[],
      'total': 0.0,
    });
  }

  void removeTable(int index) {
    tables.removeAt(index);
  }

  void toggleTableStatus(int index) {
    tables[index]['isOccupied'] = !tables[index]['isOccupied'];
    tables.refresh();
  }

  void _updateTableStatus(int tableIndex) {
    final orders = (tables[tableIndex]['orders'] as List<Map<String, dynamic>>);
    tables[tableIndex]['isOccupied'] = orders.isNotEmpty;
    tables.refresh();
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
