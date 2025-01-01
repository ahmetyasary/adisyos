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
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                TableService.to.addTable(controller.text.toUpperCase());
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
          () => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: TableService.to.tables.length,
            itemBuilder: (context, index) => _buildTableCard(index),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCard(int index) {
    final table = TableService.to.tables[index];
    final isOccupied = table['isOccupied'] as bool;

    return GestureDetector(
      onTap: () => Get.to(() => TableDetailView(
            tableNumber: index + 1,
            tableName: table['name'],
            isOccupied: isOccupied,
            tableIndex: index,
          )),
      onLongPress: () {
        final RenderBox button = Get.context!.findRenderObject() as RenderBox;
        final RenderBox overlay = Navigator.of(Get.context!)
            .overlay!
            .context
            .findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero),
                ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );

        showMenu(
          context: Get.context!,
          position: position,
          items: [
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
          }
        });
      },
      child: Card(
        color: isOccupied
            ? Colors.red.withOpacity(0.8)
            : Colors.green.withOpacity(0.8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOccupied ? 'Dolu' : 'Müsait',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
