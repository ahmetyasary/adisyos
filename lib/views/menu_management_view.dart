import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/themes/app_theme.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  void _showAddMenuDialog() {
    final TextEditingController controller = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('add_menu'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'menu_name'.tr,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _submitAddMenu(controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => _submitAddMenu(controller),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _submitAddMenu(TextEditingController controller) {
    if (controller.text.trim().isNotEmpty) {
      MenuService.to.addMenu(controller.text.trim());
      Get.back();
    }
  }

  void _showEditMenuDialog(int menuIndex, String currentName) {
    final TextEditingController controller =
        TextEditingController(text: currentName);

    Get.dialog(
      AlertDialog(
        title: Text('edit_menu'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'menu_name'.tr,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                MenuService.to.updateMenu(menuIndex, controller.text.trim());
                Get.back();
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _showDeleteMenuConfirmation(int menuIndex, String menuName) {
    Get.dialog(
      AlertDialog(
        title: Text('delete_menu'.tr),
        content: Text('"$menuName" ${'delete_menu_confirm'.tr}'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              MenuService.to.removeMenu(menuIndex);
              Get.back();
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(int menuIndex) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('add_item'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'item_name'.tr,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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
            onPressed: () =>
                _submitAddItem(menuIndex, nameController, priceController),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _submitAddItem(
    int menuIndex,
    TextEditingController nameController,
    TextEditingController priceController,
  ) {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) return;

    final price = double.tryParse(
        priceController.text.trim().replaceAll(',', '.'));
    if (price == null || price < 0) {
      Get.snackbar(
        'error'.tr,
        'invalid_price'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        colorText: Colors.white,
      );
      return;
    }

    MenuService.to.addMenuItem(menuIndex, nameController.text.trim(), price);
    Get.back();
  }

  void _showEditItemDialog(int menuIndex, int itemIndex, String currentName,
      double currentPrice) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    final TextEditingController priceController =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    Get.dialog(
      AlertDialog(
        title: Text('edit_item'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'item_name'.tr,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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
              if (nameController.text.trim().isEmpty ||
                  priceController.text.trim().isEmpty) return;

              final price = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'));
              if (price == null || price < 0) {
                Get.snackbar(
                  'error'.tr,
                  'invalid_price'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
                return;
              }

              MenuService.to.updateMenuItem(
                  menuIndex, itemIndex, nameController.text.trim(), price);
              Get.back();
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
            tooltip: 'add_menu'.tr,
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
          () => MenuService.to.menus.isEmpty
              ? Center(
                  child: Text(
                    'no_menus'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
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
                              menu['name'] as String,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${(menu['items'] as List).length} ürün',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppTheme.successColor),
                                  onPressed: () =>
                                      _showAddItemDialog(menuIndex),
                                  tooltip: 'add_item'.tr,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppTheme.accentColor),
                                  onPressed: () => _showEditMenuDialog(
                                      menuIndex, menu['name'] as String),
                                  tooltip: 'edit_menu'.tr,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.errorColor),
                                  onPressed: () =>
                                      _showDeleteMenuConfirmation(
                                          menuIndex, menu['name'] as String),
                                  tooltip: 'delete_menu'.tr,
                                ),
                              ],
                            ),
                          ),
                          if ((menu['items'] as List).isNotEmpty) ...[
                            const Divider(height: 1),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (menu['items'] as List).length,
                              itemBuilder: (context, itemIndex) {
                                final item =
                                    (menu['items'] as List)[itemIndex]
                                        as Map<String, dynamic>;
                                return ListTile(
                                  leading: const Icon(Icons.fastfood,
                                      color: Colors.grey),
                                  title: Text(item['name'] as String),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₺${(item['price'] as double).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: AppTheme.accentColor,
                                            size: 20),
                                        onPressed: () => _showEditItemDialog(
                                          menuIndex,
                                          itemIndex,
                                          item['name'] as String,
                                          item['price'] as double,
                                        ),
                                        tooltip: 'edit_item'.tr,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppTheme.errorColor,
                                            size: 20),
                                        onPressed: () =>
                                            MenuService.to.removeMenuItem(
                                          menuIndex,
                                          itemIndex,
                                        ),
                                        tooltip: 'delete'.tr,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
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
