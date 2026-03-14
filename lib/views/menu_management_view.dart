import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Design tokens ──────────────────────────────────────────
const _bg          = Color(0xFFF5F6FA);
const _card        = Colors.white;
const _orange      = Color(0xFFF5A623);
const _orangeLight = Color(0xFFFFF3E0);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec     = Color(0xFF9B9B9B);
const _border      = Color(0xFFEEEEEE);

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  // ── Dialog helpers (all logic unchanged) ──────────────────

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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Page header ──────────────────────────────
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: _card,
                border: const Border(bottom: BorderSide(color: _border)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: _textPrimary),
                    onPressed: () => Get.back(),
                  ),
                  Text(
                    'menu_management'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // Add menu button
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: _showAddMenuDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44F5A623),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'add_menu'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────
            Expanded(
              child: Obx(
                () => MenuService.to.menus.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _textSec.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 48,
                                color: _textSec,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_menus'.tr,
                              style: const TextStyle(
                                color: _textSec,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _showAddMenuDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'add_menu'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: MenuService.to.menus.length,
                        itemBuilder: (context, menuIndex) {
                          final menu = MenuService.to.menus[menuIndex];
                          return _MenuCard(
                            menu: menu,
                            menuIndex: menuIndex,
                            onAddItem: () => _showAddItemDialog(menuIndex),
                            onEditMenu: () => _showEditMenuDialog(
                                menuIndex, menu['name'] as String),
                            onDeleteMenu: () => _showDeleteMenuConfirmation(
                                menuIndex, menu['name'] as String),
                            onEditItem: (itemIndex, name, price) =>
                                _showEditItemDialog(
                                    menuIndex, itemIndex, name, price),
                            onDeleteItem: (itemIndex) =>
                                MenuService.to.removeMenuItem(
                                    menuIndex, itemIndex),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _MenuCard ──────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.menu,
    required this.menuIndex,
    required this.onAddItem,
    required this.onEditMenu,
    required this.onDeleteMenu,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final Map<String, dynamic> menu;
  final int menuIndex;
  final VoidCallback onAddItem;
  final VoidCallback onEditMenu;
  final VoidCallback onDeleteMenu;
  final void Function(int itemIndex, String name, double price) onEditItem;
  final void Function(int itemIndex) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final items = menu['items'] as List;
    final menuName = menu['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Menu header ──────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 18, color: _orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menuName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        '${items.length} ürün',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                _IconBtn(
                  icon: Icons.add_circle_outline_rounded,
                  color: AppTheme.successColor,
                  tooltip: 'add_item'.tr,
                  onTap: onAddItem,
                ),
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: _orange,
                  tooltip: 'edit_menu'.tr,
                  onTap: onEditMenu,
                ),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  tooltip: 'delete_menu'.tr,
                  onTap: onDeleteMenu,
                ),
              ],
            ),
          ),

          // ── Items list ───────────────────────────────
          if (items.isNotEmpty) ...[
            const Divider(height: 1, color: _border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _border),
              itemBuilder: (context, itemIndex) {
                final item = items[itemIndex] as Map<String, dynamic>;
                final itemName = item['name'] as String;
                final itemPrice = item['price'] as double;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fastfood_rounded,
                          size: 14,
                          color: _textSec,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _orangeLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₺${itemPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _IconBtn(
                        icon: Icons.edit_outlined,
                        color: _orange,
                        tooltip: 'edit_item'.tr,
                        onTap: () =>
                            onEditItem(itemIndex, itemName, itemPrice),
                        size: 18,
                      ),
                      _IconBtn(
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.errorColor,
                        tooltip: 'delete'.tr,
                        onTap: () => onDeleteItem(itemIndex),
                        size: 18,
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
  }
}

// ── _IconBtn ───────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}
