import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/themes/app_theme.dart';

class TableDetailView extends StatefulWidget {
  final int tableNumber;
  final String tableName;
  final bool isOccupied;
  final int tableIndex;

  const TableDetailView({
    super.key,
    required this.tableNumber,
    required this.tableName,
    required this.isOccupied,
    required this.tableIndex,
  });

  @override
  State<TableDetailView> createState() => _TableDetailViewState();
}

class _TableDetailViewState extends State<TableDetailView> {
  int _selectedMenuIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _safeMenuIndex {
    final count = MenuService.to.menus.length;
    if (count == 0) return 0;
    return _selectedMenuIndex.clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Order list
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildOrderHeader(),
                  Expanded(child: _buildOrderList()),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          // Right side - Menu
          Expanded(
            flex: 3,
            child: Container(
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
              child: Column(
                children: [
                  if (_isSearching) _buildSearchBar() else _buildCategoryTabs(),
                  Expanded(child: _buildMenuGrid()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.tableName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Obx(() {
            final total = TableService.to.getTotal(widget.tableIndex);
            final discount = TableService.to.getDiscount(widget.tableIndex);
            final finalTotal =
                TableService.to.getTotalWithDiscount(widget.tableIndex);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (discount > 0) ...[
                  Text(
                    '₺${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '-₺${discount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                Text(
                  '${'total'.tr}: ₺${finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return Obx(() {
      final orders = TableService.to.getOrders(widget.tableIndex);
      if (orders.isEmpty) {
        return Center(
          child: Text(
            'no_orders_yet'.tr,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        );
      }
      return ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderItem(
            name: order['name'] as String,
            quantity: order['quantity'] as int,
            price: order['price'] as double,
            index: index,
          );
        },
      );
    });
  }

  Widget _buildOrderItem({
    required String name,
    required int quantity,
    required double price,
    required int index,
  }) {
    return Dismissible(
      key: ValueKey('${name}_order'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        TableService.to.removeOrder(widget.tableIndex, index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            // Decrement button
            InkWell(
              onTap: () =>
                  TableService.to.decrementOrder(widget.tableIndex, index),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.remove, size: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${quantity}x',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            // Increment button
            InkWell(
              onTap: () =>
                  TableService.to.addOrder(widget.tableIndex, name, price),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.add, size: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style:
                    const TextStyle(fontSize: 15, color: Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₺${(price * quantity).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () =>
                  TableService.to.removeOrder(widget.tableIndex, index),
              borderRadius: BorderRadius.circular(4),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(Icons.add_circle_outline, 'new'.tr,
                AppTheme.accentColor, _handleNewOrder),
            _buildActionButton(Icons.call_split, 'split'.tr,
                AppTheme.infoColor, _handleSplit),
            _buildActionButton(Icons.discount, 'discount'.tr,
                AppTheme.warningColor, _handleDiscount),
            _buildActionButton(
                Icons.print, 'print'.tr, Colors.grey[700]!, _handlePrint),
            _buildActionButton(Icons.compare_arrows, 'move'.tr,
                AppTheme.accentColor, _handleMove),
            _buildActionButton(Icons.payment, 'pay'.tr,
                AppTheme.successColor, _handlePayment),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'search_menu'.tr,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          prefixIcon:
              Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Colors.white),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(
        () => ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: MenuService.to.menus.length,
          itemBuilder: (context, index) {
            final menu = MenuService.to.menus[index];
            final isSelected = index == _safeMenuIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedMenuIndex = index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    menu['name'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Obx(() {
      final menus = MenuService.to.menus;

      if (menus.isEmpty) {
        return Center(
          child: Text(
            'no_menu_defined'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }

      List<Map<String, dynamic>> items;
      if (_isSearching && _searchQuery.isNotEmpty) {
        // Search across all menus
        items = [];
        for (final menu in menus) {
          for (final item in (menu['items'] as List)) {
            final itemMap = item as Map<String, dynamic>;
            if ((itemMap['name'] as String)
                .toLowerCase()
                .contains(_searchQuery)) {
              items.add(itemMap);
            }
          }
        }
      } else {
        final safeIdx = _safeMenuIndex;
        items = List<Map<String, dynamic>>.from(
          (menus[safeIdx]['items'] as List).map((i) => i as Map<String, dynamic>),
        );
      }

      if (items.isEmpty) {
        return Center(
          child: Text(
            _isSearching
                ? 'Sonuç bulunamadı'
                : 'no_menu_defined'.tr,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth < 300
              ? 2
              : constraints.maxWidth < 500
                  ? 3
                  : 4;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => TableService.to.addOrder(
                  widget.tableIndex,
                  item['name'] as String,
                  item['price'] as double,
                ),
                borderRadius: BorderRadius.circular(16),
                child: _buildMenuCard(
                  item['name'] as String,
                  '₺${(item['price'] as double).toStringAsFixed(2)}',
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _buildMenuCard(String name, String price) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEE),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.fastfood, size: 40, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Clear table (new order)
  void _handleNewOrder() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'info'.tr,
        'table_already_empty'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.infoColor,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('clear_table'.tr),
        content: Text('clear_table_confirm'.tr),
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
              TableService.to.clearTable(widget.tableIndex);
              Get.back();
              Get.snackbar(
                'success'.tr,
                'table_cleared'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.successColor,
                colorText: Colors.white,
              );
            },
            child: Text('clear'.tr),
          ),
        ],
      ),
    );
  }

  // Split bill
  void _handleSplit() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'warning'.tr,
        'empty_no_split'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final TextEditingController peopleController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('split_bill'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${'total'.tr}: ₺${TableService.to.getTotalWithDiscount(widget.tableIndex).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: peopleController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'how_many_people'.tr,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.people),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final people = int.tryParse(peopleController.text);
              if (people != null && people > 1) {
                final total = TableService.to
                    .getTotalWithDiscount(widget.tableIndex);
                final perPerson = total / people;
                Get.back();

                Get.dialog(
                  AlertDialog(
                    title: Text('bill_split_result'.tr),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'total_amount'.tr,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          '₺${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '$people Kişi',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'per_person'.tr,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          '₺${perPerson.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        child: Text('close'.tr),
                      ),
                    ],
                  ),
                );
              } else {
                Get.snackbar(
                  'error'.tr,
                  'valid_people_count'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('calculate'.tr),
          ),
        ],
      ),
    );
  }

  // Apply discount
  void _handleDiscount() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'warning'.tr,
        'empty_no_discount'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final TextEditingController discountController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('apply_discount'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${'total'.tr}: ₺${TableService.to.getTotal(widget.tableIndex).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'discount_percent'.tr,
                border: const OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final discount = double.tryParse(discountController.text);
              if (discount != null && discount > 0 && discount <= 100) {
                TableService.to
                    .applyDiscount(widget.tableIndex, discount);
                Get.back();
                Get.snackbar(
                  'success'.tr,
                  'discount_applied'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.successColor,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'error'.tr,
                  'valid_discount'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('apply'.tr),
          ),
        ],
      ),
    );
  }

  // Print receipt (shows formatted receipt dialog)
  void _handlePrint() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'warning'.tr,
        'empty_no_print'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final total = TableService.to.getTotal(widget.tableIndex);
    final discount = TableService.to.getDiscount(widget.tableIndex);
    final finalTotal = TableService.to.getTotalWithDiscount(widget.tableIndex);

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long),
            const SizedBox(width: 8),
            Text('print'.tr),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  widget.tableName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(),
              ...orders.map((order) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${order['quantity']}x ',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Expanded(
                            child: Text(order['name'] as String,
                                overflow: TextOverflow.ellipsis)),
                        Text(
                            '₺${((order['price'] as double) * (order['quantity'] as int)).toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
              const Divider(),
              if (discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('subtotal'.tr),
                    Text('₺${total.toStringAsFixed(2)}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('discount'.tr),
                    Text('-₺${discount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppTheme.warningColor)),
                  ],
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('total'.tr,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  Text('₺${finalTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('close'.tr),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: Text('printing'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Get.back();
              Get.snackbar(
                'success'.tr,
                'printing'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.successColor,
                colorText: Colors.white,
              );
            },
          ),
        ],
      ),
    );
  }

  // Move orders to another table
  void _handleMove() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'warning'.tr,
        'empty_no_move'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('move_orders'.tr),
        content: SizedBox(
          width: 300,
          height: 350,
          child: Obx(
            () {
              final otherTables = TableService.to.tables
                  .asMap()
                  .entries
                  .where((e) => e.key != widget.tableIndex)
                  .toList();

              if (otherTables.isEmpty) {
                return Center(
                  child: Text(
                    'Başka masa yok.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              return ListView.builder(
                itemCount: otherTables.length,
                itemBuilder: (context, i) {
                  final entry = otherTables[i];
                  final tableIdx = entry.key;
                  final table = entry.value;
                  return ListTile(
                    title: Text(table['name'] as String),
                    subtitle: Text(
                      (table['isOccupied'] as bool)
                          ? 'occupied_status'.tr
                          : 'available_status'.tr,
                      style: TextStyle(
                        color: (table['isOccupied'] as bool)
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      final tName = table['name'] as String;
                      TableService.to
                          .moveAllOrdersToTable(widget.tableIndex, tableIdx);
                      Get.back();
                      Get.back();
                      Get.snackbar(
                        'success'.tr,
                        '$tName ${'moved_to_table'.tr}',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppTheme.successColor,
                        colorText: Colors.white,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  // Take payment
  void _handlePayment() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'warning'.tr,
        'empty_no_pay'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final total = TableService.to.getTotal(widget.tableIndex);
    final discount = TableService.to.getDiscount(widget.tableIndex);
    final finalTotal = TableService.to.getTotalWithDiscount(widget.tableIndex);

    Get.dialog(
      AlertDialog(
        title: Text('pay_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'table_label'.tr}: ${widget.tableName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('subtotal'.tr),
                Text('₺${total.toStringAsFixed(2)}'),
              ],
            ),
            if (discount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('discount'.tr),
                  Text(
                    '-₺${discount.toStringAsFixed(2)}',
                    style:
                        const TextStyle(color: AppTheme.warningColor),
                  ),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'total'.tr,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '₺${finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              TableService.to.recordPayment(widget.tableIndex);
              Get.back();
              Get.back();
              Get.snackbar(
                'success'.tr,
                'payment_received'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.successColor,
                colorText: Colors.white,
              );
            },
            child: Text('pay'.tr),
          ),
        ],
      ),
    );
  }
}
