import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:adisyos/views/table_detail_view.dart';
import 'package:adisyos/views/public_menu_view.dart';
import 'package:adisyos/services/table_service.dart';

// Design tokens
const _bg = Color(0xFFF5F6FA);
const _card = Colors.white;
const _orange = Color(0xFFF5A623);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF9B9B9B);
const _occupied = Color(0xFFFF6B6B);
const _available = Color(0xFF52C97F);

class TablesView extends StatelessWidget {
  const TablesView({super.key});

  void _showAddTableDialog() {
    final TextEditingController controller = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('add_table'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'table_name'.tr,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          onSubmitted: (_) => _submitAddTable(controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => _submitAddTable(controller),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _submitAddTable(TextEditingController controller) {
    if (controller.text.trim().isNotEmpty) {
      TableService.to.addTable(controller.text.trim().toUpperCase());
      Get.back();
    }
  }

  void _showEditTableDialog(int index, String currentName) {
    final TextEditingController controller =
        TextEditingController(text: currentName);

    Get.dialog(
      AlertDialog(
        title: Text('edit_table'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'table_name'.tr,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
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
                TableService.to
                    .updateTableName(index, controller.text.trim().toUpperCase());
                Get.back();
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final tableName = TableService.to.tables[index]['name'];
    Get.dialog(
      AlertDialog(
        title: Text('delete_table'.tr),
        content: Text('delete_table_confirmation'.trParams({'s': tableName})),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('no'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              TableService.to.removeTable(index);
              Get.back();
            },
            child: Text('yes'.tr),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, int index) {
    final tableName = TableService.to.tables[index]['name'] as String;
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'QR — $tableName',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: 'adisyos://menu?table=$tableName',
              version: QrVersions.auto,
              size: 200,
            ),
            const SizedBox(height: 8),
            Text(
              'adisyos://menu?table=$tableName',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Bu kodu masaya yerleştirerek müşterilerin menüyü görmesini sağlayabilirsiniz.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => PublicMenuView(tableName: tableName));
            },
            child: const Text('Menüyü Önizle'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showTableContextMenu(BuildContext context, int index, Offset position) {
    final tableName = TableService.to.tables[index]['name'] as String;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, color: Colors.blue),
              const SizedBox(width: 8),
              Text('edit'.tr),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'qr',
          child: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('QR Kod'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, color: Colors.red),
              const SizedBox(width: 8),
              Text('delete'.tr),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        _showDeleteConfirmation(index);
      } else if (value == 'edit') {
        _showEditTableDialog(index, tableName);
      } else if (value == 'qr') {
        _showQrDialog(context, index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTableDialog,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _textPrimary),
                    onPressed: () => Get.back(),
                  ),
                  Expanded(
                    child: Text(
                      'tables'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: _textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // Stats row
            Obx(() {
              final tables = TableService.to.tables;
              final total = tables.length;
              final occupied =
                  tables.where((t) => t['isOccupied'] as bool).length;
              final available = total - occupied;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Toplam: $total',
                      color: _textPrimary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Dolu: $occupied',
                      color: _occupied,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Boş: $available',
                      color: _available,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Grid
            Expanded(
              child: Obx(
                () => TableService.to.tables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_bar_rounded,
                                size: 64, color: _textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'no_tables'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: _textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth < 500
                              ? 2
                              : constraints.maxWidth < 800
                                  ? 3
                                  : 4;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: TableService.to.tables.length,
                            itemBuilder: (context, index) =>
                                _buildTableCard(context, index),
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

  Widget _buildTableCard(BuildContext context, int index) {
    final table = TableService.to.tables[index];
    final isOccupied = table['isOccupied'] as bool;
    final total = table['total'] as double;
    final status = isOccupied ? 'occupied_status'.tr : 'available_status'.tr;

    return GestureDetector(
      onTap: () => Get.to(() => TableDetailView(
            tableNumber: index + 1,
            tableName: table['name'] as String,
            isOccupied: isOccupied,
            tableIndex: index,
          )),
      onLongPressStart: (details) =>
          _showTableContextMenu(context, index, details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isOccupied
                ? _occupied.withOpacity(0.4)
                : _available.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Status dot top-right
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOccupied ? _occupied : _available,
                ),
              ),
            ),
            // Center content
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Table icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? _occupied.withOpacity(0.1)
                          : _available.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.table_bar_rounded,
                      color: isOccupied ? _occupied : _available,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Table name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      table['name'] as String,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? _occupied.withOpacity(0.1)
                          : _available.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOccupied ? _occupied : _available,
                      ),
                    ),
                  ),
                  if (isOccupied && total > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
