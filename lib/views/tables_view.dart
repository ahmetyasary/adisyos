import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/views/pin_screen.dart';
import 'package:orderix/views/table_detail_view.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/widgets/day_toggle_card.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Design tokens ─────────────────────────────────────────────
Color get _bg => AppColors.bg;
Color get _chip => AppColors.chipBg;
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
Color get _textPrimary => AppColors.textPrimary;
Color get _textSecondary => AppColors.textSec;
Color get _border => AppColors.border;
const _occupied = Color(0xFFFF3B30);
const _available = Color(0xFF34C759);

Color get _tableFreeBg => AppColors.card;
Color get _tableOccupiedBg =>
    AppColors.isDark ? const Color(0xFF2A1F1A) : const Color(0xFFFFF4EC);

class TablesView extends StatefulWidget {
  const TablesView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<TablesView> {
  final _selectedSectionId = Rx<String?>(null);

  // ── Day not started dialog ──────────────────────────────────

  void _showDayNotStartedDialog({
    required int tableNumber,
    required String tableName,
    required bool isOccupied,
    required int tableIndex,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  CupertinoIcons.sun_max_fill,
                  size: 32,
                  color: _orange,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Gün Başlatılmadı',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sipariş alabilmek için önce\ngünü başlatmanız gerekmektedir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Primary action full-width, then dismiss below
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    final sn = StaffService.to.currentStaffIdentifier;
                    final id = sn.isNotEmpty
                        ? sn
                        : (AuthController.to.user.value?.email ?? '');
                    await DayService.to.startDay(id);
                    AppToast.success('İyi çalışmalar!',
                        title: 'Gün Başlatıldı',
                        duration: const Duration(seconds: 2));
                    Get.to(() => TableDetailView(
                          tableNumber: tableNumber,
                          tableName: tableName,
                          isOccupied: isOccupied,
                          tableIndex: tableIndex,
                        ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Günü Başlat',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: Get.back,
                  child: Text(
                    'Vazgeç',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: _textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Staff logout with day-end confirmation ──────────────────

  void _handleStaffLogout() {
    final name = StaffService.to.currentStaffIdentifier;

    // Block logout if any table still has an active order
    final hasOrders =
        TableService.to.tables.any((t) => t['isOccupied'] == true);
    if (hasOrders) {
      Get.dialog(
        Dialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.table_bar_rounded,
                      size: 32, color: Color(0xFFFF3B30)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Açık Sipariş Var',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tüm masalar kapatılmadan\nçıkış yapılamaz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: Get.back,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Tamam',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final dayActive = name.isNotEmpty && DayService.to.isDayStartedBy(name);

    if (dayActive) {
      Get.dialog(
        Dialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(CupertinoIcons.sun_max_fill,
                      size: 32, color: Color(0xFFFF9500)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Günü Bitir ve Çıkış Yap',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktif gününüz var. Çıkış yaparsanız\ngün otomatik olarak bitecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      await DayService.to.endDay(name);
                      StaffService.to.clearCurrentStaff();
                      Get.offAll(() => const PinScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Günü Bitir ve Çıkış Yap',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: Get.back,
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      StaffService.to.clearCurrentStaff();
      Get.offAll(() => const PinScreen());
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────

  void _showAddTableDialog() {
    final ctrl = TextEditingController();
    AppDialog.form(
      title: 'add_table'.tr,
      confirmText: 'save'.tr,
      cancelText: 'cancel'.tr,
      onConfirm: () => _submitAddTable(ctrl),
      body: AppDialogTextField(
        controller: ctrl,
        label: 'table_name'.tr,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
      ),
    );
  }

  Future<void> _submitAddTable(TextEditingController ctrl) async {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final error = await TableService.to
        .addTable(name.toUpperCase(), sectionId: _selectedSectionId.value);
    if (error != null) {
      // Keep the dialog open so the user can pick a different name.
      AppToast.error(error);
      return;
    }
    Get.back();
  }

  // ── Section management (moved here from Settings) ────────────

  void _showAddSectionDialog() {
    final ctrl = TextEditingController();
    AppDialog.form(
      title: 'Bölüm Ekle',
      confirmText: 'Ekle',
      cancelText: 'cancel'.tr,
      onConfirm: () async {
        if (ctrl.text.trim().isEmpty) return;
        await SectionService.to.addSection(ctrl.text.trim());
        Get.back();
      },
      body: AppDialogTextField(
        controller: ctrl,
        label: 'Bölüm Adı',
        hintText: 'örn: İç Alan, Bahçe',
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }

  void _showSectionContextMenu(
      BuildContext context, Map<String, dynamic> section, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(CupertinoIcons.pencil, color: Color(0xFF007AFF)),
            const SizedBox(width: 8),
            Text('edit'.tr),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30)),
            const SizedBox(width: 8),
            Text('delete'.tr),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        _showEditSectionDialog(section);
      } else if (value == 'delete') {
        _confirmDeleteSection(section);
      }
    });
  }

  void _showEditSectionDialog(Map<String, dynamic> section) {
    final ctrl = TextEditingController(text: section['name'] as String);
    AppDialog.form(
      title: 'Bölümü Düzenle',
      confirmText: 'save'.tr,
      cancelText: 'cancel'.tr,
      onConfirm: () async {
        if (ctrl.text.trim().isEmpty) return;
        await SectionService.to
            .updateSection(section['id'] as String, ctrl.text.trim());
        Get.back();
      },
      body: AppDialogTextField(
        controller: ctrl,
        label: 'Bölüm Adı',
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }

  void _confirmDeleteSection(Map<String, dynamic> section) async {
    final ok = await AppDialog.confirm(
      icon: CupertinoIcons.trash,
      iconColor: const Color(0xFFFF3B30),
      title: 'Bölümü Sil',
      message: '"${section['name']}" silinsin mi?',
      confirmText: 'yes'.tr,
      cancelText: 'no'.tr,
      destructive: true,
    );
    if (ok) {
      // If the deleted section was the active filter, reset to "Tümü".
      if (_selectedSectionId.value == section['id']) {
        _selectedSectionId.value = null;
      }
      await SectionService.to.deleteSection(section['id'] as String);
    }
  }

  void _showEditTableDialog(int index, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    final table = TableService.to.tables[index];
    // Track the section selection locally inside the dialog
    String? selectedSectionId = table['sectionId'] as String?;
    final originalSectionId = selectedSectionId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final sections = SectionService.to.sections;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 40,
                      offset: Offset(0, 12)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(CupertinoIcons.pencil,
                              size: 20, color: _orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'edit_table'.tr,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _chip,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(CupertinoIcons.xmark,
                                    size: 15, color: _textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: _border),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Table name field ─────────────────────
                        Text(
                          'MASA ADI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textSecondary,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _chip,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: TextField(
                            controller: ctrl,
                            textCapitalization: TextCapitalization.characters,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        // ── Section picker ───────────────────────
                        if (sections.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'BÖLÜM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _textSecondary,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // "No section" chip
                                _sectionChip(
                                  label: 'Bölümsüz',
                                  icon: CupertinoIcons.nosign,
                                  selected: selectedSectionId == null,
                                  onTap: () => setDialogState(
                                      () => selectedSectionId = null),
                                ),
                                const SizedBox(width: 8),
                                ...sections.map((s) {
                                  final sid = s['id'] as String;
                                  final name = s['name'] as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _sectionChip(
                                      label: name,
                                      icon: _getSectionIcon(name),
                                      selected: selectedSectionId == sid,
                                      onTap: () => setDialogState(
                                          () => selectedSectionId = sid),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // ── Footer ──────────────────────────────────
                  Divider(height: 1, color: _border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: _textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('cancel'.tr),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = ctrl.text.trim();
                              if (name.isEmpty) return;
                              final sectionChanged =
                                  selectedSectionId != originalSectionId;
                              TableService.to.updateTable(
                                index,
                                name.toUpperCase(),
                                sectionId: selectedSectionId,
                                sectionChanged: sectionChanged,
                              );
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('save'.tr),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _orange : _bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _orange : _border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: selected ? Colors.white : _textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) async {
    final tableName = TableService.to.tables[index]['name'];
    final ok = await AppDialog.confirm(
      icon: CupertinoIcons.trash,
      iconColor: const Color(0xFFFF3B30),
      title: 'delete_table'.tr,
      message: 'delete_table_confirmation'.trParams({'s': '$tableName'}),
      confirmText: 'yes'.tr,
      cancelText: 'no'.tr,
      destructive: true,
    );
    if (ok) TableService.to.removeTable(index);
  }

  void _showTableContextMenu(BuildContext context, int index, Offset position) {
    final tableName = TableService.to.tables[index]['name'] as String;
    final isAdmin = AuthController.to.isAdmin;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(CupertinoIcons.pencil, color: Color(0xFF007AFF)),
            const SizedBox(width: 8),
            Text('edit'.tr),
          ]),
        ),
        if (isAdmin)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30)),
              const SizedBox(width: 8),
              Text('delete'.tr),
            ]),
          ),
      ],
    ).then((value) {
      if (value == 'delete')
        _showDeleteConfirmation(index);
      else if (value == 'edit') _showEditTableDialog(index, tableName);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────

  IconData _getSectionIcon(String name) => _sectionIconFor(name);

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: Obx(() {
        if (StaffService.to.hasActiveStaff) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: _showAddTableDialog,
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(CupertinoIcons.add),
        );
      }),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header bar ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border, width: 1)),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
                right: 8,
              ),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    ShellLeading(
                        embedded: widget.embedded, color: _textPrimary),
                    Text(
                      'tables'.tr,
                      style: TextStyle(
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
                            style: TextStyle(
                                fontSize: 12, color: _textSecondary)),
                      );
                    }),
                    const Spacer(),
                    Obx(() {
                      if (!StaffService.to.hasActiveStaff)
                        return const SizedBox.shrink();
                      return IconButton(
                        icon: Icon(CupertinoIcons.square_arrow_right,
                            size: 18, color: _textSecondary),
                        tooltip: 'Çıkış',
                        onPressed: () => _handleStaffLogout(),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Day start/end ───────────────────────────────
            ResponsiveContent(
              width: ContentWidth.wide,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DayToggleCard(dense: true),
              ),
            ),

            // ── Stats row + section pills ───────────────────
            Obx(() {
              final tables = TableService.to.tables;
              final total = tables.length;
              final occupied =
                  tables.where((t) => t['isOccupied'] as bool).length;
              final free = total - occupied;
              final sections = SectionService.to.sections;

              return ResponsiveContent(
                width: ContentWidth.wide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                              child: _StatBox(
                                  label: 'TOPLAM',
                                  value: '$total',
                                  valueColor: _textPrimary)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _StatBox(
                                  label: 'DOLU',
                                  value: '$occupied',
                                  valueColor: _occupied)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _StatBox(
                                  label: 'BOŞ',
                                  value: '$free',
                                  valueColor: _available)),
                        ],
                      ),
                    ),
                    if (sections.isNotEmpty || AuthController.to.isAdmin) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Obx(() {
                          final isAdmin = AuthController.to.isAdmin;
                          return Row(
                            children: [
                              _SectionPill(
                                label: 'Tümü',
                                icon: CupertinoIcons.square_grid_2x2_fill,
                                selected: _selectedSectionId.value == null,
                                onTap: () => _selectedSectionId.value = null,
                              ),
                              ...sections.map((s) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _SectionPill(
                                      label: s['name'] as String,
                                      icon:
                                          _getSectionIcon(s['name'] as String),
                                      selected:
                                          _selectedSectionId.value == s['id'],
                                      onTap: () => _selectedSectionId.value =
                                          s['id'] as String,
                                      onLongPress: isAdmin
                                          ? (pos) => _showSectionContextMenu(
                                              context, s, pos)
                                          : null,
                                    ),
                                  )),
                              if (isAdmin)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _AddSectionPill(
                                      onTap: _showAddSectionDialog),
                                ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // ── Table grid ─────────────────────────────────
            Expanded(
              child: ResponsiveContent(
                width: ContentWidth.wide,
                child: Obx(() {
                  final allTables = TableService.to.tables;
                  final sectionId = _selectedSectionId.value;

                  List<Map<String, dynamic>> tables;

                  if (sectionId != null) {
                    final sections = SectionService.to.sections;
                    final selectedSection = sections.firstWhere(
                        (s) => s['id'] == sectionId,
                        orElse: () => {});
                    final sectionName = selectedSection.isNotEmpty
                        ? (selectedSection['name'] as String).toLowerCase()
                        : '';

                    tables = allTables.where((t) {
                      final tSectionId = t['sectionId'];
                      final tName = (t['name'] as String).toLowerCase();

                      // Match by exact sectionId OR if the table's name contains the section's name
                      return tSectionId == sectionId ||
                          (sectionName.isNotEmpty &&
                              tName.contains(sectionName));
                    }).toList();
                  } else {
                    // "Tümü" view: occupied tables first, available tables after
                    tables = List<Map<String, dynamic>>.from(allTables)
                      ..sort((a, b) {
                        final aOccupied = a['isOccupied'] as bool;
                        final bOccupied = b['isOccupied'] as bool;
                        if (aOccupied == bOccupied) return 0;
                        return aOccupied ? -1 : 1;
                      });
                  }

                  if (allTables.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_bar_rounded,
                              size: 64, color: _textSecondary),
                          const SizedBox(height: 16),
                          Text('no_tables'.tr,
                              style: TextStyle(
                                  fontSize: 16, color: _textSecondary)),
                        ],
                      ),
                    );
                  }

                  if (tables.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_bar_rounded,
                              size: 48, color: _textSecondary),
                          const SizedBox(height: 12),
                          Text('Bu bölümde masa yok',
                              style: TextStyle(
                                  fontSize: 15, color: _textSecondary)),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth < 500
                        ? 3
                        : constraints.maxWidth < 820
                            ? 4
                            : constraints.maxWidth < 1040
                                ? 5
                                : 6;
                    final compact = cols >= 3 && constraints.maxWidth < 500;
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16,
                          MediaQuery.of(context).padding.bottom + 88),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: compact ? 0.85 : 0.95,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (context, i) {
                        final table = tables[i];
                        final actualIndex = allTables.indexOf(table);
                        return _TableCard(
                          table: table,
                          index: actualIndex,
                          compact: compact,
                          onTap: () {
                            final staffName =
                                StaffService.to.currentStaffIdentifier;
                            final id = staffName.isNotEmpty
                                ? staffName
                                : (AuthController.to.user.value?.email ?? '');
                            if (!DayService.to.isDayStartedBy(id)) {
                              _showDayNotStartedDialog(
                                tableNumber: actualIndex + 1,
                                tableName: table['name'] as String,
                                isOccupied: table['isOccupied'] as bool,
                                tableIndex: actualIndex,
                              );
                              return;
                            }
                            Get.to(() => TableDetailView(
                                  tableNumber: actualIndex + 1,
                                  tableName: table['name'] as String,
                                  isOccupied: table['isOccupied'] as bool,
                                  tableIndex: actualIndex,
                                ));
                          },
                          onLongPress: (pos) =>
                              _showTableContextMenu(context, actualIndex, pos),
                        );
                      },
                    );
                  });
                }),
              ),
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
  const _StatBox(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final void Function(Offset)? onLongPress;

  const _SectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart:
          onLongPress == null ? null : (d) => onLongPress!(d.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _orange : _card,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.fromBorderSide(BorderSide(color: _border, width: 1)),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Color(0x33FF9500),
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ]
              : const [
                  BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 4,
                      offset: Offset(0, 1))
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed "＋ Bölüm" pill that opens the add-section dialog. Only shown to
/// admins; sits at the end of the section filter row on the tables screen.
class _AddSectionPill extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSectionPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _orange.withOpacity(0.35), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add, size: 15, color: _orange),
            SizedBox(width: 5),
            Text(
              'Bölüm',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section identity helpers ──────────────────────────────────

IconData _sectionIconFor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('bahçe') || lower.contains('garden'))
    return CupertinoIcons.tree;
  if (lower.contains('teras') || lower.contains('terrace'))
    return CupertinoIcons.sun_max;
  if (lower.contains('salon') || lower.contains('iç'))
    return CupertinoIcons.house;
  if (lower.contains('bar')) return CupertinoIcons.drop_fill;
  if (lower.contains('paket') || lower.contains('gel'))
    return CupertinoIcons.bag_fill;
  if (lower.contains('vip') || lower.contains('özel'))
    return CupertinoIcons.star;
  return CupertinoIcons.tag;
}

/// Stable per-section accent colour so cards from different sections read
/// distinctly at a glance. Deliberately excludes the status green/red and the
/// brand orange so it never collides with occupancy or price cues.
const List<Color> _sectionPalette = [
  Color(0xFF007AFF), // blue
  Color(0xFFAF52DE), // purple
  Color(0xFF5856D6), // indigo
  Color(0xFF30B0C7), // teal
  Color(0xFF32ADE6), // cyan
  Color(0xFFBF5AF2), // magenta
  Color(0xFFA2845E), // brown
];

Color _sectionColorFor(String section) {
  if (section.isEmpty) return _textSecondary;
  final hash = section.codeUnits.fold(0, (a, b) => a + b);
  return _sectionPalette[hash % _sectionPalette.length];
}

class _TableCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final int index;
  final bool compact;
  final VoidCallback onTap;
  final void Function(Offset) onLongPress;

  const _TableCard({
    required this.table,
    required this.index,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = table['name'] as String;
    final isOccupied = table['isOccupied'] as bool;
    final rawTotal = (table['total'] as num?)?.toDouble() ?? 0.0;
    final discount = (table['discount'] as num?)?.toDouble() ?? 0.0;
    final total = (rawTotal - discount).clamp(0.0, double.infinity);
    final accentColor = isOccupied ? _occupied : _available;

    // Derive section label from sectionId (live lookup) then fallback to name parse
    final sectionId = table['sectionId'] as String?;
    final sectionFromService = SectionService.to.nameById(sectionId);
    final parts = name.trim().split(' ');
    final String section;
    final String number;
    if (sectionFromService != null && sectionFromService.isNotEmpty) {
      section = sectionFromService.toUpperCase();
      number = parts.last;
    } else if (parts.length > 1) {
      number = parts.last;
      section = parts.sublist(0, parts.length - 1).join(' ');
    } else {
      section = 'MASA';
      number = name;
    }

    final double pad = compact ? 10.0 : 14.0;
    final double numFont = compact ? 26.0 : 30.0;
    final double radius = compact ? 14.0 : 18.0;
    final sectionColor = _sectionColorFor(section);
    final sectionIcon = _sectionIconFor(section);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (d) => onLongPress(d.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          // Occupied: warm tint; free: surface card (adapts to dark).
          color: isOccupied ? _tableOccupiedBg : _tableFreeBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border(
            left: BorderSide(color: accentColor, width: compact ? 3.5 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: isOccupied
                  ? _occupied.withOpacity(AppColors.isDark ? 0.22 : 0.08)
                  : (AppColors.isDark
                      ? const Color(0x66000000)
                      : const Color(0x08000000)),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(pad - 1, pad, pad, pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Zone 1: colour-coded section tag + occupied icon ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
                    decoration: BoxDecoration(
                      color: sectionColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sectionIcon,
                            size: compact ? 11 : 13, color: sectionColor),
                        SizedBox(width: compact ? 3 : 4),
                        Flexible(
                          child: Text(
                            section,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11.5,
                              fontWeight: FontWeight.w700,
                              color: sectionColor,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOccupied) ...[
                  SizedBox(width: compact ? 3 : 4),
                  Icon(CupertinoIcons.person_fill,
                      size: compact ? 13 : 15,
                      color: _occupied.withOpacity(0.6)),
                ],
              ],
            ),

            // ── Zone 2: table number (hero) ─────────────────────
            Text(
              number,
              style: TextStyle(
                fontSize: numFont,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Zone 3: status + price / action ────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                isOccupied
                    ? _PriceBadge(total: total, compact: compact)
                    : _EmptyBadge(compact: compact),
                const Spacer(),
                GestureDetector(
                  onTapDown: (d) => onLongPress(d.globalPosition),
                  child: isOccupied
                      ? Icon(CupertinoIcons.ellipsis,
                          size: compact ? 16 : 18, color: _textSecondary)
                      : Container(
                          padding: EdgeInsets.all(compact ? 4 : 5),
                          decoration: BoxDecoration(
                            color: _available.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.add,
                              size: compact ? 14 : 16, color: _available),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Orange price badge shown on occupied tables.
class _PriceBadge extends StatelessWidget {
  final double total;
  final bool compact;
  const _PriceBadge({required this.total, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Obx(() => Text(
            '${SettingsService.cs}${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w800,
              color: _orange,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
    );
  }
}

/// Green "available" badge shown on empty tables.
class _EmptyBadge extends StatelessWidget {
  final bool compact;
  const _EmptyBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 6 : 7,
          height: compact ? 6 : 7,
          decoration: const BoxDecoration(
            color: _available,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: compact ? 4 : 5),
        Text(
          'Müsait',
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w600,
            color: _available,
          ),
        ),
      ],
    );
  }
}
