import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:adisyos/views/table_detail_view.dart';
import 'package:adisyos/views/public_menu_view.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/services/section_service.dart';
import 'package:adisyos/services/staff_service.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bg            = Color(0xFFF2F2F7);
const _card          = Colors.white;
const _orange        = Color(0xFFFF9500);
const _textPrimary   = Color(0xFF1C1C1E);
const _textSecondary = Color(0xFF8E8E93);
const _separator     = Color(0xFFE5E5EA);
const _occupied      = Color(0xFFFF3B30);
const _available     = Color(0xFF34C759);

class TablesView extends StatefulWidget {
  const TablesView({super.key});

  @override
  State<TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<TablesView> {
  final _selectedSectionId = Rx<String?>(null);

  // ── Dialogs ─────────────────────────────────────────────────

  void _showAddTableDialog() {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Text('add_table'.tr),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: 'table_name'.tr, border: const OutlineInputBorder()),
        textCapitalization: TextCapitalization.characters,
        autofocus: true,
        onSubmitted: (_) => _submitAddTable(ctrl),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        ElevatedButton(
            onPressed: () => _submitAddTable(ctrl), child: Text('save'.tr)),
      ],
    ));
  }

  void _submitAddTable(TextEditingController ctrl) {
    if (ctrl.text.trim().isNotEmpty) {
      TableService.to.addTable(ctrl.text.trim().toUpperCase(),
          sectionId: _selectedSectionId.value);
      Get.back();
    }
  }

  void _showEditTableDialog(int index, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    Get.dialog(AlertDialog(
      title: Text('edit_table'.tr),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: 'table_name'.tr, border: const OutlineInputBorder()),
        textCapitalization: TextCapitalization.characters,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              TableService.to
                  .updateTableName(index, ctrl.text.trim().toUpperCase());
              Get.back();
            }
          },
          child: Text('save'.tr),
        ),
      ],
    ));
  }

  void _showDeleteConfirmation(int index) {
    final tableName = TableService.to.tables[index]['name'];
    Get.dialog(AlertDialog(
      title: Text('delete_table'.tr),
      content: Text('delete_table_confirmation'.trParams({'s': tableName})),
      actions: [
        TextButton(onPressed: Get.back, child: Text('no'.tr)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            TableService.to.removeTable(index);
            Get.back();
          },
          child: Text('yes'.tr),
        ),
      ],
    ));
  }

  void _showQrDialog(BuildContext context, int index) {
    final tableName = TableService.to.tables[index]['name'] as String;
    Get.dialog(AlertDialog(
      title: Row(children: [
        const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
        const SizedBox(width: 8),
        Expanded(
            child: Text('QR — $tableName',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        QrImageView(
            data: 'adisyos://menu?table=$tableName',
            version: QrVersions.auto,
            size: 200),
        const SizedBox(height: 8),
        Text('adisyos://menu?table=$tableName',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text(
            'Bu kodu masaya yerleştirerek müşterilerin menüyü görmesini sağlayabilirsiniz.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            Get.to(() => PublicMenuView(tableName: tableName));
          },
          child: const Text('Menüyü Önizle'),
        ),
        ElevatedButton(
            onPressed: Get.back, child: const Text('Kapat')),
      ],
    ));
  }

  void _showTableContextMenu(
      BuildContext context, int index, Offset position) {
    final tableName = TableService.to.tables[index]['name'] as String;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            Text('edit'.tr),
          ]),
        ),
        PopupMenuItem(
          value: 'qr',
          child: Row(children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('QR Kod'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            Text('delete'.tr),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'delete') _showDeleteConfirmation(index);
      else if (value == 'edit') _showEditTableDialog(index, tableName);
      else if (value == 'qr') _showQrDialog(context, index);
    });
  }

  // ── Build ────────────────────────────────────────────────────

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
            // ── Header bar ─────────────────────────────────
            Container(
              height: 56,
              color: _card,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: _textPrimary),
                    onPressed: () => Get.back(),
                  ),
                  Text(
                    'tables'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Obx(() {
                    final name = StaffService.to.currentStaffIdentifier;
                    if (name.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 12, color: _textSecondary)),
                    );
                  }),
                ],
              ),
            ),

            // ── Stats row + section pills ───────────────────
            Obx(() {
              final tables   = TableService.to.tables;
              final total    = tables.length;
              final occupied = tables.where((t) => t['isOccupied'] as bool).length;
              final free     = total - occupied;
              final sections = SectionService.to.sections;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Stat boxes
                    _StatBox(label: 'TOPLAM', value: '$total', valueColor: _textPrimary),
                    const SizedBox(width: 8),
                    _StatBox(label: 'DOLU',   value: '$occupied', valueColor: _occupied),
                    const SizedBox(width: 8),
                    _StatBox(label: 'BOŞ',    value: '$free',     valueColor: _available),

                    // Section pills flush to the right
                    if (sections.isNotEmpty) ...[
                      const Spacer(),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Obx(() => Row(
                            children: [
                              _SectionPill(
                                label: 'Tümü',
                                selected: _selectedSectionId.value == null,
                                onTap: () => _selectedSectionId.value = null,
                              ),
                              ...sections.map((s) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _SectionPill(
                                      label: s['name'] as String,
                                      selected: _selectedSectionId.value == s['id'],
                                      onTap: () => _selectedSectionId.value = s['id'] as String,
                                    ),
                                  )),
                            ],
                          )),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // ── Table grid ─────────────────────────────────
            Expanded(
              child: Obx(() {
                final allTables = TableService.to.tables;
                final sectionId = _selectedSectionId.value;
                final tables    = sectionId == null
                    ? allTables
                    : allTables.where((t) => t['sectionId'] == sectionId).toList();

                if (allTables.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_bar_rounded, size: 64, color: _textSecondary),
                        const SizedBox(height: 16),
                        Text('no_tables'.tr,
                            style: TextStyle(fontSize: 16, color: _textSecondary)),
                      ],
                    ),
                  );
                }

                if (tables.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_bar_rounded, size: 48, color: _textSecondary),
                        const SizedBox(height: 12),
                        Text('Bu bölümde masa yok',
                            style: TextStyle(fontSize: 15, color: _textSecondary)),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth < 500 ? 2
                      : constraints.maxWidth < 800 ? 3 : 4;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, i) {
                      final table       = tables[i];
                      final actualIndex = allTables.indexOf(table);
                      return _TableCard(
                        table: table,
                        index: actualIndex,
                        onTap: () => Get.to(() => TableDetailView(
                              tableNumber: actualIndex + 1,
                              tableName:   table['name'] as String,
                              isOccupied:  table['isOccupied'] as bool,
                              tableIndex:  actualIndex,
                            )),
                        onLongPress: (pos) =>
                            _showTableContextMenu(context, actualIndex, pos),
                      );
                    },
                  );
                });
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatBox({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SectionPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _orange : _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Color(0x33FF9500),
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ]
              : const [
                  BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final int index;
  final VoidCallback onTap;
  final void Function(Offset) onLongPress;

  const _TableCard({
    required this.table,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name       = table['name'] as String;
    final isOccupied = table['isOccupied'] as bool;
    final total      = (table['total'] as num?)?.toDouble() ?? 0.0;
    final statusColor = isOccupied ? _occupied : _available;
    final iconBg      = isOccupied
        ? _occupied.withOpacity(0.10)
        : _available.withOpacity(0.10);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (d) => onLongPress(d.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
          ],
        ),
        child: Stack(
          children: [
            // Status dot top-right
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon area
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.table_bar_rounded,
                          size: 38,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Table name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOccupied ? 'Dolu' : 'Boş',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),

                  // Hesap label (only when occupied)
                  if (isOccupied) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('HESAP  ',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _textSecondary)),
                        Expanded(
                          child: Text(
                            '₺${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _orange,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
