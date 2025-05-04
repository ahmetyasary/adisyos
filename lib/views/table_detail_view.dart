import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/table_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Arama işlevi
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sol taraf - Sipariş listesi
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Sipariş listesi başlığı
                  Container(
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
                              color: Colors.black),
                        ),
                        Obx(
                          () => Text(
                            '${('total'.tr)}: ₺${TableService.to.getTotal(widget.tableIndex).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sipariş listesi
                  Expanded(
                    child: Obx(
                      () {
                        final orders =
                            TableService.to.getOrders(widget.tableIndex);
                        return orders.isEmpty
                            ? Center(
                                child: Text(
                                  'Henüz sipariş yok',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  return Dismissible(
                                    key: Key('order_${order['id']}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 16),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) {
                                      setState(() {
                                        TableService.to.removeOrder(
                                            widget.tableIndex, index);
                                      });
                                    },
                                    child: _buildOrderItem(
                                      order['name'],
                                      order['quantity'],
                                      order['price'],
                                    ),
                                  );
                                },
                              );
                      },
                    ),
                  ),
                  // Alt butonlar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                            Icons.add_circle_outline, 'new'.tr, Colors.blue),
                        _buildActionButton(
                            Icons.call_split, 'split'.tr, Colors.green),
                        _buildActionButton(
                            Icons.discount, 'discount'.tr, Colors.red),
                        _buildActionButton(
                            Icons.print, 'print'.tr, Colors.grey),
                        _buildActionButton(
                            Icons.compare_arrows, 'move'.tr, Colors.blue),
                        _buildActionButton(
                            Icons.payment, 'pay'.tr, Colors.green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sağ taraf - Menü
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
                  // Menü kategorileri
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Obx(
                      () => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: MenuService.to.menus.length,
                        itemBuilder: (context, index) {
                          final menu = MenuService.to.menus[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryButton(
                              menu['name'],
                              index == _selectedMenuIndex,
                              onTap: () =>
                                  setState(() => _selectedMenuIndex = index),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Menü içeriği
                  Expanded(
                    child: Obx(
                      () {
                        if (MenuService.to.menus.isEmpty) {
                          return Center(
                            child: Text(
                              'Tanımlı menü yok.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: MenuService
                              .to.menus[_selectedMenuIndex]['items'].length,
                          itemBuilder: (context, index) {
                            final item = MenuService
                                .to.menus[_selectedMenuIndex]['items'][index];
                            return InkWell(
                              onTap: () => TableService.to.addOrder(
                                widget.tableIndex,
                                item['name'],
                                item['price'],
                              ),
                              child: _buildMenuItem(
                                item['name'],
                                'assets/images/coffee.jpg',
                                '₺${item['price'].toStringAsFixed(2)}',
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(String name, int quantity, double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            '${quantity}x',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
          Text(
            '₺${(price * quantity).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String label, bool isSelected,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String name, String imageUrl, String price) {
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
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.coffee, size: 48, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 14,
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
}
