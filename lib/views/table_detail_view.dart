import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/services/inventory_service.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg            = Color(0xFFF2F2F7);
const _card          = Colors.white;
const _orange        = Color(0xFFFF9500);
const _textPrimary   = Color(0xFF1C1C1E);
const _textSecondary = Color(0xFF8E8E93);
const _border        = Color(0xFFE5E5EA);
const _menuItemBg    = Color(0xFFFFF4E0);

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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(context),
            // Main content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category sidebar
                  _buildCategorySidebar(),
                  // Menu section
                  Expanded(
                    flex: 3,
                    child: _buildMenuSection(),
                  ),
                  // Order panel
                  _buildOrderPanel(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
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
            widget.tableName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off : Icons.search,
              color: _textSecondary,
            ),
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
          Obx(() {
            final orders = TableService.to.getOrders(widget.tableIndex);
            final count = orders.fold<int>(
                0, (sum, o) => sum + (o['quantity'] as int));
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Icon(Icons.receipt_long, color: _textSecondary),
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar() {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Obx(
              () => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: MenuService.to.menus.length,
                itemBuilder: (context, index) {
                  final menu = MenuService.to.menus[index];
                  final isSelected = index == _safeMenuIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMenuIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _orange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? const Border(
                                left: BorderSide(color: _orange, width: 3),
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFFBF4D), _orange],
                                    )
                                  : null,
                              color: isSelected ? null : _bg,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: _orange.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 20,
                              color: isSelected ? Colors.white : _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            menu['name'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? _orange : _textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // History button at the bottom of sidebar
          _buildHistoryButton(),
        ],
      ),
    );
  }

  Widget _buildHistoryButton() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: GestureDetector(
        onTap: () {
          // History action placeholder
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _menuItemBg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history, size: 20, color: _orange),
              ),
              const SizedBox(height: 4),
              const Text(
                'Geçmiş',
                style: TextStyle(
                  fontSize: 9,
                  color: _orange,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      color: _bg,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_menu'.tr,
                hintStyle: const TextStyle(
                    color: _textSecondary, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: _textSecondary, size: 20),
                suffixIcon: const Icon(Icons.tune,
                    color: _textSecondary, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: _orange, width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                  _isSearching = value.isNotEmpty;
                });
              },
            ),
          ),
          Expanded(child: _buildMenuGrid()),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Obx(() {
      final menus = MenuService.to.menus;

      if (menus.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu,
                  size: 48, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                'no_menu_defined'.tr,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      List<Map<String, dynamic>> items;
      if (_isSearching && _searchQuery.isNotEmpty) {
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
          (menus[safeIdx]['items'] as List)
              .map((i) => i as Map<String, dynamic>),
        );
      }

      if (items.isEmpty) {
        return Center(
          child: Text(
            _isSearching ? 'Sonuç bulunamadı' : 'no_menu_defined'.tr,
            style: const TextStyle(color: _textSecondary, fontSize: 16),
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
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final name = item['name'] as String;
              final isOut = InventoryService.to.isOutOfStock(name);
              final isLow = InventoryService.to.isLowStock(name);
              final isTracked = InventoryService.to.isTracked(name);
              final stockVal = InventoryService.to.getStock(name);

              return InkWell(
                onTap: () {
                  if (isOut) {
                    Get.snackbar(
                      'warning'.tr,
                      '$name stokta yok!',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.warningColor,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  TableService.to.addOrder(
                    widget.tableIndex,
                    name,
                    item['price'] as double,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    _buildMenuCard(
                      name,
                      '₺${(item['price'] as double).toStringAsFixed(2)}',
                      dimmed: isOut,
                    ),
                    if (isTracked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOut
                                ? const Color(0xFFFF3B30)
                                : isLow
                                    ? _orange
                                    : const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut ? 'Bitti' : '$stockVal',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _buildMenuCard(String name, String price, {bool dimmed = false}) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dimmed
            ? []
            : const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
                BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFBF4D), _orange],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(
                  Icons.fastfood_rounded,
                  size: 36,
                  color: Colors.white,
                ),
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
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFBF4D), _orange],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: _orange.withOpacity(0.35), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildOrderPanel(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(-2, 0)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sipariş Detayı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _textPrimary,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.tableName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _border, height: 1),
          // Order list
          Expanded(
            child: Obx(() {
              final orders = TableService.to.getOrders(widget.tableIndex);
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 48, color: _textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'no_orders_yet'.tr,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final name = order['name'] as String;
                  final quantity = order['quantity'] as int;
                  final price = order['price'] as double;
                  final lineTotal = price * quantity;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Qty controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyBtn(
                              icon: Icons.remove,
                              onTap: () => TableService.to
                                  .decrementOrder(widget.tableIndex, index),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${quantity}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QtyBtn(
                              icon: Icons.add,
                              onTap: () => TableService.to
                                  .addOrder(widget.tableIndex, name, price),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₺${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () => TableService.to
                              .removeOrder(widget.tableIndex, index),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline,
                                size: 18, color: _textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          const Divider(color: _border, height: 1),
          // Payment summary
          Obx(() {
            final subtotal = TableService.to.getTotal(widget.tableIndex);
            final discount = TableService.to.getDiscount(widget.tableIndex);
            final finalTotal =
                TableService.to.getTotalWithDiscount(widget.tableIndex);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Ara Toplam',
                    value: '₺${subtotal.toStringAsFixed(2)}',
                  ),
                  if (discount > 0)
                    _SummaryRow(
                      label: 'İskonto',
                      value: '-₺${discount.toStringAsFixed(2)}',
                      valueColor: _orange,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _textPrimary,
                            ),
                      ),
                      Text(
                        '₺${finalTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          // Action buttons row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.add_circle_outline,
                    label: 'new'.tr,
                    color: AppTheme.accentColor,
                    onTap: _handleNewOrder,
                  ),
                  _ActionBtn(
                    icon: Icons.call_split,
                    label: 'split'.tr,
                    color: AppTheme.infoColor,
                    onTap: _handleSplit,
                  ),
                  _ActionBtn(
                    icon: Icons.discount,
                    label: 'discount'.tr,
                    color: AppTheme.warningColor,
                    onTap: _handleDiscount,
                  ),
                  _ActionBtn(
                    icon: Icons.print,
                    label: 'print'.tr,
                    color: const Color(0xFF616161),
                    onTap: _handlePrint,
                  ),
                  _ActionBtn(
                    icon: Icons.compare_arrows,
                    label: 'move'.tr,
                    color: AppTheme.accentColor,
                    onTap: _handleMove,
                  ),
                ],
              ),
            ),
          ),
          // Checkout button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _handlePayment,
                child: const Text(
                  'Ödeme Al',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        content: SizedBox(
          width: 300,
          child: Column(
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
        content: SizedBox(
          width: 300,
          child: Column(
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

  // Print receipt — generates a real PDF
  Future<void> _handlePrint() async {
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

    final subtotal = TableService.to.getTotal(widget.tableIndex);
    final discount = TableService.to.getDiscount(widget.tableIndex);
    final finalTotal =
        TableService.to.getTotalWithDiscount(widget.tableIndex);

    try {
      final prefs = await SharedPreferences.getInstance();
      final companyName =
          prefs.getString('companyName') ?? 'Adisyos';

      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    companyName,
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    widget.tableName,
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(font: regularFont, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 4),
                ...orders.map(
                  (order) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${order['quantity']}x  ${order['name']}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 12),
                        ),
                        pw.Text(
                          'TL ${((order['price'] as double) * (order['quantity'] as int)).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.SizedBox(height: 4),
                if (discount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Ara Toplam',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                      pw.Text('TL ${subtotal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Iskonto',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                      pw.Text('-TL ${discount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                    ],
                  ),
                ],
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOPLAM',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14)),
                    pw.Text(
                        'TL ${finalTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    'Tesekkur ederiz!',
                    style:
                        pw.TextStyle(font: regularFont, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (format) async => doc.save());
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'PDF olusturulurken hata: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        colorText: Colors.white,
      );
    }
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
    String selectedMethod = 'cash';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                      style: const TextStyle(color: AppTheme.warningColor),
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
              const SizedBox(height: 16),
              Text(
                'pay_method'.tr,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _PayMethodChip(
                    label: 'pay_cash'.tr,
                    icon: Icons.payments_rounded,
                    value: 'cash',
                    selected: selectedMethod == 'cash',
                    onTap: () => setState(() => selectedMethod = 'cash'),
                  ),
                  _PayMethodChip(
                    label: 'pay_card'.tr,
                    icon: Icons.credit_card_rounded,
                    value: 'card',
                    selected: selectedMethod == 'card',
                    onTap: () => setState(() => selectedMethod = 'card'),
                  ),
                  _PayMethodChip(
                    label: 'pay_transfer'.tr,
                    icon: Icons.account_balance_rounded,
                    value: 'transfer',
                    selected: selectedMethod == 'transfer',
                    onTap: () => setState(() => selectedMethod = 'transfer'),
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
                TableService.to.recordPayment(widget.tableIndex,
                    paymentMethod: selectedMethod);
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
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFBF4D), _orange],
                )
              : null,
          color: selected ? null : _bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: _orange.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.white : _textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: _textSecondary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? _textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
