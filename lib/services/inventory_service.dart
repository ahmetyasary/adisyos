import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class InventoryService extends GetxService {
  static InventoryService get to => Get.find();

  /// itemName -> stock count. -1 = not tracked (unlimited).
  final RxMap<String, int> stock = <String, int>{}.obs;
  late String _filePath;

  static const int lowStockThreshold = 5;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/inventory.json';
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final str = prefs.getString('inventory');
        if (str != null) {
          final map = json.decode(str) as Map;
          stock.assignAll(
              map.map((k, v) => MapEntry(k as String, (v as num).toInt())));
        }
      } else {
        final file = File(_filePath);
        if (await file.exists()) {
          final str = await file.readAsString();
          final map = json.decode(str) as Map;
          stock.assignAll(
              map.map((k, v) => MapEntry(k as String, (v as num).toInt())));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading inventory: $e');
    }
  }

  Future<void> _save() async {
    try {
      final str = json.encode(stock);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('inventory', str);
      } else {
        final file = File(_filePath);
        await file.writeAsString(str);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving inventory: $e');
    }
  }

  /// Returns stock level, or -1 if not tracked (unlimited).
  int getStock(String itemName) => stock[itemName] ?? -1;

  bool isTracked(String itemName) => stock.containsKey(itemName);

  bool isLowStock(String itemName) {
    final s = getStock(itemName);
    return s != -1 && s > 0 && s <= lowStockThreshold;
  }

  bool isOutOfStock(String itemName) {
    final s = getStock(itemName);
    return s != -1 && s <= 0;
  }

  void setStock(String itemName, int count) {
    stock[itemName] = count;
    stock.refresh();
    _save();
  }

  void removeTracking(String itemName) {
    stock.remove(itemName);
    stock.refresh();
    _save();
  }

  /// Called when a sale is recorded — decrements tracked items.
  void decrementForSale(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      final current = getStock(name);
      if (current != -1) {
        stock[name] = (current - qty).clamp(0, current);
      }
    }
    stock.refresh();
    _save();
  }

  List<MapEntry<String, int>> get lowStockItems {
    final items = stock.entries
        .where((e) => e.value >= 0 && e.value <= lowStockThreshold)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return items;
  }
}
