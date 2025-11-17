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
                          () {
                            final total = TableService.to.getTotal(widget.tableIndex);
                            final discount = TableService.to.getDiscount(widget.tableIndex);
                            final finalTotal = TableService.to.getTotalWithDiscount(widget.tableIndex);
                            
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
                                  '${('total'.tr)}: ₺${finalTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
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
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                            Icons.add_circle_outline,
                            'new'.tr,
                            AppTheme.accentColor,
                            _handleNewOrder),
                        _buildActionButton(Icons.call_split, 'split'.tr,
                            AppTheme.infoColor, _handleSplit),
                        _buildActionButton(Icons.discount, 'discount'.tr,
                            AppTheme.warningColor, _handleDiscount),
                        _buildActionButton(Icons.print, 'print'.tr,
                            Colors.grey[700]!, _handlePrint),
                        _buildActionButton(Icons.compare_arrows, 'move'.tr,
                            AppTheme.accentColor, _handleMove),
                        _buildActionButton(Icons.payment, 'pay'.tr,
                            AppTheme.successColor, _handlePayment),
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

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Yeni sipariş (Masayı temizle)
  void _handleNewOrder() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Bilgi',
        'Masa zaten boş',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.infoColor,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Masayı Temizle'),
        content: const Text('Mevcut siparişler silinecek. Onaylıyor musunuz?'),
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
                'Başarılı',
                'Masa temizlendi',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.successColor,
                colorText: Colors.white,
              );
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // Hesap bölme
  void _handleSplit() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Masa boş. Hesap bölünemez.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final TextEditingController peopleController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Hesap Böl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Toplam: ₺${TableService.to.getTotalWithDiscount(widget.tableIndex).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: peopleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kaç kişiye bölünecek?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
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
                final total = TableService.to.getTotalWithDiscount(widget.tableIndex);
                final perPerson = total / people;
                
                Get.back();
                
                // Sonucu göster
                Get.dialog(
                  AlertDialog(
                    title: const Text('Hesap Bölümü'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Toplam Tutar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₺${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          '$people Kişi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kişi Başı',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                );
              } else {
                Get.snackbar(
                  'Hata',
                  'Geçerli bir kişi sayısı girin (minimum 2)',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Hesapla'),
          ),
        ],
      ),
    );
  }

  // İndirim uygula
  void _handleDiscount() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Masa boş. İndirim uygulanamaz.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    final TextEditingController discountController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('İndirim Uygula'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Toplam: ₺${TableService.to.getTotal(widget.tableIndex).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'İndirim Yüzdesi (%)',
                border: OutlineInputBorder(),
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
                TableService.to.applyDiscount(widget.tableIndex, discount);
                Get.back();
                Get.snackbar(
                  'Başarılı',
                  '%$discount indirim uygulandı',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.successColor,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Hata',
                  'Geçerli bir indirim yüzdesi girin (1-100)',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  // Yazdır
  void _handlePrint() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Masa boş. Yazdırılacak sipariş yok.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    Get.snackbar(
      'Başarılı',
      'Adisyon yazdırılıyor...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.successColor,
      colorText: Colors.white,
    );
  }

  // Sipariş taşı
  void _handleMove() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Masa boş. Taşınacak sipariş yok.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Sipariş Taşı'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: Obx(
            () => ListView.builder(
              itemCount: TableService.to.tables.length,
              itemBuilder: (context, index) {
                if (index == widget.tableIndex) return const SizedBox.shrink();
                final table = TableService.to.tables[index];
                return ListTile(
                  title: Text(table['name']),
                  subtitle: Text(
                    table['isOccupied'] ? 'Dolu' : 'Müsait',
                    style: TextStyle(
                      color: table['isOccupied']
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    TableService.to
                        .moveAllOrdersToTable(widget.tableIndex, index);
                    Get.back();
                    Get.back();
                    Get.snackbar(
                      'Başarılı',
                      '${table['name']} masasına taşındı',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.successColor,
                      colorText: Colors.white,
                    );
                  },
                );
              },
            ),
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

  // Ödeme al
  void _handlePayment() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Masa boş. Ödeme alınamaz.',
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
        title: const Text('Ödeme Al'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masa: ${widget.tableName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Ara Toplam: ₺${total.toStringAsFixed(2)}'),
            if (discount > 0) ...[
              Text('İndirim: -₺${discount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.warningColor)),
            ],
            const Divider(),
            Text(
              'Toplam: ₺${finalTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
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
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              TableService.to.clearTable(widget.tableIndex);
              Get.back();
              Get.back();
              Get.snackbar(
                'Başarılı',
                'Ödeme alındı. Masa temizlendi.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.successColor,
                colorText: Colors.white,
              );
            },
            child: const Text('Ödeme Al'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String label, bool isSelected,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
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
