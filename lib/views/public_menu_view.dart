import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/settings_service.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Colors.white;
const _orange = Color(0xFFF5A623);
const _orangeLight = Color(0xFFFFF3E0);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec = Color(0xFF9B9B9B);
const _border = Color(0xFFEEEEEE);
const _menuItemBg = Color(0xFFFFF8EE);

/// Read-only menu — shown when a table QR code is previewed.
class PublicMenuView extends StatelessWidget {
  final String? tableName;
  const PublicMenuView({super.key, this.tableName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: _card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back, color: _textPrimary),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Menümüz',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _textPrimary),
                        ),
                        if (tableName != null && tableName!.isNotEmpty)
                          Text(
                            tableName!,
                            style: const TextStyle(
                                fontSize: 13, color: _textSec),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _orangeLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Adisyos',
                      style: TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final cs = SettingsService.cs;
                final menus = MenuService.to.menus;
                if (menus.isEmpty) {
                  return const Center(
                    child: Text('Menü bulunamadı.',
                        style: TextStyle(color: _textSec)),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
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
                                    fontSize: 18,
                                    color: _textPrimary),
                              ),
                            ],
                          ),
                        ),
                        ...items.map((item) {
                          final itemMap = item as Map<String, dynamic>;
                          final name = itemMap['name'] as String;
                          final price =
                              (itemMap['price'] as num).toDouble();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _menuItemBg,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.fastfood_rounded,
                                    color: _orange.withOpacity(0.7),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: _textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _orangeLight,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$cs${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: _orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
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
}
