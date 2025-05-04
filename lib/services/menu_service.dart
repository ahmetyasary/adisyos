import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
    final directory = await getApplicationDocumentsDirectory();
    _menusFilePath = '${directory.path}/menus.json';
    await _loadMenus();
  }

  Future<void> _loadMenus() async {
    try {
      final file = File(_menusFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        menus.assignAll(jsonList.map((item) {
          final Map<String, dynamic> menu = Map<String, dynamic>.from(item);
          menu['items'] = List<Map<String, dynamic>>.from(
              menu['items'].map((item) => Map<String, dynamic>.from(item)));
          return menu;
        }));
      } else {
        // Varsayılan menüleri yükle
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
        await _saveMenus();
      }
    } catch (e) {
      print('Error loading menus: $e');
    }
  }

  Future<void> _saveMenus() async {
    try {
      final file = File(_menusFilePath);
      final jsonString = json.encode(menus);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving menus: $e');
    }
  }

  void addMenu(String name) {
    menus.add({
      'name': name,
      'items': [],
    });
    _saveMenus();
  }

  void addMenuItem(int menuIndex, String name, double price) {
    menus[menuIndex]['items'].add({
      'name': name,
      'price': price,
    });
    menus.refresh();
    _saveMenus();
  }

  void removeMenu(int index) {
    menus.removeAt(index);
    _saveMenus();
  }

  void removeMenuItem(int menuIndex, int itemIndex) {
    menus[menuIndex]['items'].removeAt(itemIndex);
    menus.refresh();
    _saveMenus();
  }
}
