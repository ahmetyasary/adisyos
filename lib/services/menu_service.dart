import 'package:get/get.dart';

class MenuService extends GetxService {
  static MenuService get to => Get.find();

  final RxList<Map<String, dynamic>> menus = <Map<String, dynamic>>[
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
  ].obs;

  void addMenu(String name) {
    menus.add({
      'name': name,
      'items': [],
    });
  }

  void addMenuItem(int menuIndex, String name, double price) {
    menus[menuIndex]['items'].add({
      'name': name,
      'price': price,
    });
    menus.refresh();
  }

  void removeMenu(int index) {
    menus.removeAt(index);
  }

  void removeMenuItem(int menuIndex, int itemIndex) {
    menus[menuIndex]['items'].removeAt(itemIndex);
    menus.refresh();
  }
}
