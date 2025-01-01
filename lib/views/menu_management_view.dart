import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  void _showAddMenuDialog() {
    final TextEditingController menuNameController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('add_menu'.tr),
        content: TextField(
          controller: menuNameController,
          decoration: InputDecoration(
            labelText: 'menu_name'.tr,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (menuNameController.text.isNotEmpty) {
                MenuService.to.addMenu(menuNameController.text);
                Get.back();
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(int menuIndex) {
    final TextEditingController itemNameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('add_item'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemNameController,
              decoration: InputDecoration(
                labelText: 'item_name'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'price'.tr,
                border: const OutlineInputBorder(),
                prefixText: '₺',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (itemNameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                MenuService.to.addMenuItem(
                  menuIndex,
                  itemNameController.text,
                  double.parse(priceController.text),
                );
                Get.back();
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('menu_management'.tr),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMenuDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Obx(
          () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: MenuService.to.menus.length,
            itemBuilder: (context, menuIndex) {
              final menu = MenuService.to.menus[menuIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        menu['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _showAddItemDialog(menuIndex),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // Menü düzenleme işlevi
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                MenuService.to.removeMenu(menuIndex),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menu['items'].length,
                      itemBuilder: (context, itemIndex) {
                        final item = menu['items'][itemIndex];
                        return ListTile(
                          title: Text(item['name']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₺${item['price'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  // Ürün düzenleme işlevi
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => MenuService.to.removeMenuItem(
                                  menuIndex,
                                  itemIndex,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
