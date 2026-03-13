import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/views/table_detail_view.dart';
import 'package:adisyos/services/table_service.dart';

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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tables'.tr),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTableDialog,
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
          () => TableService.to.tables.isEmpty
              ? Center(
                  child: Text(
                    'no_tables'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: TableService.to.tables.length,
                      itemBuilder: (context, index) =>
                          _buildTableCard(context, index),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTableCard(BuildContext context, int index) {
    final table = TableService.to.tables[index];
    final isOccupied = table['isOccupied'] as bool;

    return GestureDetector(
      onTap: () => Get.to(() => TableDetailView(
            tableNumber: index + 1,
            tableName: table['name'] as String,
            isOccupied: isOccupied,
            tableIndex: index,
          )),
      onLongPressStart: (details) =>
          _showTableContextMenu(context, index, details.globalPosition),
      child: Card(
        elevation: 4,
        color: isOccupied
            ? const Color(0xFFE74C3C).withValues(alpha: 0.9)
            : const Color(0xFF27AE60).withValues(alpha: 0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              isOccupied ? 'occupied_status'.tr : 'available_status'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₺${(table['total'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
