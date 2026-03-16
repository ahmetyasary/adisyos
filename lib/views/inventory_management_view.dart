import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/inventory_service.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Colors.white;
const _orange = Color(0xFFF5A623);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec = Color(0xFF9B9B9B);
const _border = Color(0xFFEEEEEE);
const _colLow = Color(0xFFF5A623);
const _colOut = Color(0xFFFF6B6B);
const _colOk = Color(0xFF52C97F);

class InventoryManagementView extends StatelessWidget {
  const InventoryManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildAlertsBanner(),
            Expanded(
              child: Obx(() {
                final menus = MenuService.to.menus;
                if (menus.isEmpty) {
                  return Center(
                    child: Text(
                      'Menü tanımlı değil.',
                      style: const TextStyle(color: _textSec, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: menus.length,
                  itemBuilder: (context, menuIdx) {
                    final menu = menus[menuIdx];
                    final items = menu['items'] as List;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: _orange,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                menu['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _textPrimary),
                              ),
                            ],
                          ),
                        ),
                        ...items.map((item) {
                          final itemMap = item as Map<String, dynamic>;
                          return _InventoryItemCard(
                              itemName: itemMap['name'] as String);
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      color: _card,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _textPrimary),
            onPressed: () => Get.back(),
          ),
          const Text(
            'Stok Yönetimi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary),
          ),
          const Spacer(),
          Obx(() {
            final low = InventoryService.to.lowStockItems.length;
            if (low == 0) return const SizedBox();
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _colOut.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$low kritik',
                style: const TextStyle(
                    color: _colOut,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertsBanner() {
    return Obx(() {
      final lowItems = InventoryService.to.lowStockItems;
      if (lowItems.isEmpty) return const SizedBox();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _colOut.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colOut.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_rounded, color: _colOut, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${lowItems.length} ürün kritik stok seviyesinde: '
                '${lowItems.map((e) => '${e.key} (${e.value})').join(', ')}',
                style: const TextStyle(
                    color: _colOut, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Item Card ────────────────────────────────────────────────────────────────

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({required this.itemName});

  final String itemName;

  void _showEditDialog(BuildContext context) {
    final service = InventoryService.to;
    final current = service.getStock(itemName);
    final controller =
        TextEditingController(text: current == -1 ? '' : '$current');

    Get.dialog(
      AlertDialog(
        title: Text(itemName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stok miktarı (boş bırakırsanız sınırsız olur)',
              style: TextStyle(fontSize: 12, color: _textSec),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Miktar',
                suffixText: 'adet',
              ),
            ),
          ],
        ),
        actions: [
          if (service.isTracked(itemName))
            TextButton(
              onPressed: () {
                service.removeTracking(itemName);
                Get.back();
              },
              child: const Text('Takibi Kaldır',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                service.removeTracking(itemName);
              } else {
                final count = int.tryParse(text);
                if (count != null && count >= 0) {
                  service.setStock(itemName, count);
                }
              }
              Get.back();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = InventoryService.to;
      final stockVal = service.getStock(itemName);
      final isTracked = service.isTracked(itemName);
      final isOut = service.isOutOfStock(itemName);
      final isLow = service.isLowStock(itemName);

      final Color statusColor =
          isOut ? _colOut : isLow ? _colLow : isTracked ? _colOk : _textSec;

      final String statusText = isOut
          ? 'Stok tükendi'
          : isLow
              ? '$stockVal adet — az'
              : isTracked
                  ? '$stockVal adet'
                  : 'Sınırsız';

      return GestureDetector(
        onTap: () => _showEditDialog(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isOut || isLow)
                  ? statusColor.withOpacity(0.4)
                  : _border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  itemName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                      fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.edit_outlined, size: 16, color: _textSec),
            ],
          ),
        ),
      );
    });
  }
}
