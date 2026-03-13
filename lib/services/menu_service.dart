import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MenuService extends GetxService {
  static MenuService get to => Get.find();

  final RxList<Map<String, dynamic>> menus = <Map<String, dynamic>>[].obs;
  late final String _menusFilePath;

  @override
  void onInit() {
    super.onInit();
    _initMenusFile();
  }

  Future<void> _initMenusFile() async {
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      _menusFilePath = '${directory.path}/menus.json';
    }
    await _loadMenus();
  }

  Future<void> _loadMenus() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('menus');
        if (jsonString != null) {
          final List<dynamic> jsonList = json.decode(jsonString);
          menus.assignAll(jsonList.map((item) {
            final Map<String, dynamic> menu = Map<String, dynamic>.from(item as Map);
            menu['items'] = List<Map<String, dynamic>>.from(
                menu['items'].map((i) => Map<String, dynamic>.from(i as Map)));
            return menu;
          }));
        } else {
          _loadDefaults();
          await _saveMenus();
        }
      } else {
        final file = File(_menusFilePath);
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final List<dynamic> jsonList = json.decode(jsonString);
          menus.assignAll(jsonList.map((item) {
            final Map<String, dynamic> menu = Map<String, dynamic>.from(item as Map);
            menu['items'] = List<Map<String, dynamic>>.from(
                menu['items'].map((i) => Map<String, dynamic>.from(i as Map)));
            return menu;
          }));
        } else {
          _loadDefaults();
          await _saveMenus();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading menus: $e');
      }
    }
  }

  void _loadDefaults() {
    menus.assignAll([
      {
        'name': 'İçecekler',
        'items': [
          {'name': 'Americano', 'price': 30.0},
          {'name': 'Caffe Latte', 'price': 36.0},
          {'name': 'Caramel Latte', 'price': 40.0},
          {'name': 'Espresso', 'price': 25.0},
        ]
      },
      {
        'name': 'Tatlılar',
        'items': [
          {'name': 'Cookie', 'price': 25.0},
          {'name': 'Tiramisu', 'price': 45.0},
          {'name': 'Banana Bread', 'price': 35.0},
        ]
      },
    ]);
  }

  Future<void> _saveMenus() async {
    try {
      final jsonString = json.encode(menus);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('menus', jsonString);
      } else {
        final file = File(_menusFilePath);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving menus: $e');
      }
    }
  }

  void addMenu(String name) {
    menus.add({
      'name': name,
      'items': <Map<String, dynamic>>[],
    });
    _saveMenus();
  }

  void updateMenu(int index, String name) {
    menus[index]['name'] = name;
    menus.refresh();
    _saveMenus();
  }

  void addMenuItem(int menuIndex, String name, double price) {
    (menus[menuIndex]['items'] as List).add({
      'name': name,
      'price': price,
    });
    menus.refresh();
    _saveMenus();
  }

  void updateMenuItem(int menuIndex, int itemIndex, String name, double price) {
    final items = menus[menuIndex]['items'] as List;
    items[itemIndex] = {'name': name, 'price': price};
    menus.refresh();
    _saveMenus();
  }

  void removeMenu(int index) {
    menus.removeAt(index);
    _saveMenus();
  }

  void removeMenuItem(int menuIndex, int itemIndex) {
    (menus[menuIndex]['items'] as List).removeAt(itemIndex);
    menus.refresh();
    _saveMenus();
  }
}
