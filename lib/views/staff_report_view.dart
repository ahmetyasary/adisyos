import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/models/app_role.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/admin_pin_setup_sheet.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Design tokens ─────────────────────────────────────────────
Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
Color get _border => AppColors.borderSoft;
const _orange = Color(0xFFFF9500);
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
const _green = Color(0xFF34C759);
const _blue = Color(0xFF007AFF);

class StaffReportView extends StatelessWidget {
  const StaffReportView({super.key, this.embedded = false});

  final bool embedded;

  // Normalise a staffEmail raw value to a display key.
  // Admin logins (email addresses) and empty/unknown values all map to
  // the sentinel 'Yönetici' so they are merged into a single entry.
  static const _adminKey = 'Yönetici';

  static String _toKey(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _adminKey;
    if (raw.contains('@')) return _adminKey;
    return raw.trim();
  }

  // Build combined stats: sales + hours for each staff member.
  List<Map<String, dynamic>> _buildStats() {
    final profiles = StaffService.to.staffList;
    final sales = SalesHistoryService.to.sales;
    final shifts = ShiftService.to.shifts;
    final today = DateTime.now();

    // Aggregate sales — all admin/email/unknown entries merge into _adminKey
    final Map<String, Map<String, dynamic>> salesMap = {};
    for (final sale in sales) {
      final id = _toKey(sale['staffEmail'] as String?);
      salesMap.putIfAbsent(
          id, () => {'total': 0.0, 'count': 0, 'lastSale': null});
      salesMap[id]!['total'] = (salesMap[id]!['total'] as double) +
          ((sale['total'] as num).toDouble());
      salesMap[id]!['count'] = (salesMap[id]!['count'] as int) + 1;
      final saleDate = DateTime.tryParse(sale['date'] as String? ?? '');
      if (saleDate != null) {
        final last = salesMap[id]!['lastSale'] as DateTime?;
        if (last == null || saleDate.isAfter(last)) {
          salesMap[id]!['lastSale'] = saleDate;
        }
      }
    }

    // Today's work minutes per staff name key
    final Map<String, int> hoursMap = {};
    for (final shift in shifts) {
      final id = _toKey(shift['staffEmail'] as String?);
      if (id == _adminKey) continue; // admins don't use shift tracking
      final shiftDate = DateTime.tryParse(shift['date'] as String? ?? '');
      if (shiftDate == null) continue;
      if (shiftDate.year != today.year ||
          shiftDate.month != today.month ||
          shiftDate.day != today.day) continue;
      hoursMap[id] =
          (hoursMap[id] ?? 0) + ShiftService.to.getWorkMinutes(shift);
    }

    // Build result list — known staff profiles first
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final profile in profiles) {
      final name = profile['name'] as String;
      seen.add(name);
      final s = salesMap[name];
      result.add({
        'name': name,
        'role': profile['role'] as String? ?? 'garson',
        'isAdmin': false,
        'total': s?['total'] as double? ?? 0.0,
        'count': s?['count'] as int? ?? 0,
        'lastSale': s?['lastSale'] as DateTime?,
        'todayMinutes': hoursMap[name] ?? 0,
      });
    }

    // Add Yönetici entry if it has any sales data
    if (!seen.contains(_adminKey) && salesMap.containsKey(_adminKey)) {
      final s = salesMap[_adminKey]!;
      result.add({
        'name': _adminKey,
        'role': 'yetkili',
        'isAdmin': true,
        'total': s['total'] as double,
        'count': s['count'] as int,
        'lastSale': s['lastSale'] as DateTime?,
        'todayMinutes': 0,
      });
    }

    result
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: AuthController.to.isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddStaffDialog(context),
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(CupertinoIcons.person_add_solid),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border, width: 1)),
              ),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    ShellLeading(embedded: embedded, color: _textPrimary),
                    Text(
                      'Personel Raporu',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // ── Content ────────────────────────────────────
            Expanded(
              child: Obx(() {
                // Access all reactive sources so Obx rebuilds on changes
                StaffService.to.staffList.length;
                SalesHistoryService.to.sales.length;
                ShiftService.to.shifts.length;

                final stats = _buildStats();

                if (stats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.person_2,
                            size: 48, color: _textSec),
                        SizedBox(height: 12),
                        Text('Henüz personel eklenmedi',
                            style: TextStyle(color: _textSec, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stats.length,
                  itemBuilder: (_, i) {
                    final st = stats[i];
                    final card = _StaffCard(stats: st, rank: i + 1);
                    final isSentinel = st['isAdmin'] as bool? ?? false;
                    // Admins can long-press a real staff member to edit / delete.
                    if (!AuthController.to.isAdmin || isSentinel) return card;
                    return GestureDetector(
                      onLongPressStart: (d) => _showStaffContextMenu(
                          context, st['name'] as String, d.globalPosition),
                      child: card,
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

  // ── Staff management (moved here from Settings) ──────────────

  Future<void> _handleFirstStaffAdded() async {
    AppToast.info(
      'Bundan sonra yönetici girişi PIN ile korunacak.',
      title: 'Personel eklendi',
      duration: const Duration(seconds: 4),
    );
    if (!SettingsService.to.hasAdminPin ||
        SettingsService.to.adminPinMustChange.value ||
        SettingsService.to.adminPin.value == '1234') {
      await showAdminPinSetup(
        forced: true,
        isCreate: !SettingsService.to.hasAdminPin ||
            SettingsService.to.adminPin.value == '1234',
        title: 'Yönetici PIN’i Oluştur',
        message:
            'İlk personel eklendi. Yönetici hesabınız için 4 haneli bir PIN oluşturun. Sonraki girişlerde bu PIN istenecek.',
      );
    }
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    var selectedRole = AppRole.staff;
    AppDialog.form(
      title: 'Personel Ekle',
      confirmText: 'Ekle',
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        final pin = pinCtrl.text.trim();
        if (name.isEmpty || pin.length != 4) return;
        final firstStaff =
            await StaffService.to.addStaff(name, pin, role: selectedRole);
        Get.back();
        if (firstStaff) {
          await _handleFirstStaffAdded();
        }
      },
      body: StatefulBuilder(
        builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: nameCtrl,
              label: 'Ad Soyad',
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppDialogTextField(
              controller: pinCtrl,
              label: '4 Haneli PIN',
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            _StaffRolePicker(
              value: selectedRole,
              onChanged: (r) => setLocal(() => selectedRole = r),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffContextMenu(BuildContext context, String name, Offset pos) {
    Map<String, dynamic>? staff;
    for (final s in StaffService.to.staffList) {
      if (s['name'] == name) {
        staff = s;
        break;
      }
    }
    if (staff == null) return;
    final record = staff;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
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
        _showEditStaffDialog(record);
      } else if (value == 'delete') {
        _confirmDeleteStaff(record);
      }
    });
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final nameCtrl = TextEditingController(text: staff['name'] as String);
    final pinCtrl = TextEditingController();
    var selectedRole =
        AppRoleX.fromString(staff['role'] as String? ?? 'garson');
    AppDialog.form(
      title: 'Personeli Düzenle',
      confirmText: 'save'.tr,
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        final pin = pinCtrl.text.trim().isEmpty
            ? staff['pin'] as String
            : pinCtrl.text.trim();
        if (name.isEmpty) return;
        await StaffService.to.updateStaff(
          staff['id'] as String,
          name: name,
          pin: pin,
          role: selectedRole,
        );
        Get.back();
      },
      body: StatefulBuilder(
        builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: nameCtrl,
              label: 'Ad Soyad',
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppDialogTextField(
              controller: pinCtrl,
              label: 'Yeni PIN',
              hintText: 'Boş bırakın = değişmesin',
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            _StaffRolePicker(
              value: selectedRole,
              onChanged: (r) => setLocal(() => selectedRole = r),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStaff(Map<String, dynamic> staff) async {
    final ok = await AppDialog.confirm(
      icon: CupertinoIcons.trash,
      iconColor: const Color(0xFFFF3B30),
      title: 'Personeli Sil',
      message: '${staff['name']} silinsin mi?',
      confirmText: 'yes'.tr,
      cancelText: 'no'.tr,
      destructive: true,
    );
    if (ok) await StaffService.to.deleteStaff(staff['id'] as String);
  }
}

// ── Staff Card ────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.stats, required this.rank});

  final Map<String, dynamic> stats;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final name = stats['name'] as String;
    final total = stats['total'] as double;
    final count = stats['count'] as int;
    final lastSale = stats['lastSale'] as DateTime?;
    final todayMinutes = stats['todayMinutes'] as int;
    final isAdmin = stats['isAdmin'] as bool? ?? false;
    final roleLabel = isAdmin
        ? 'Yetkili'
        : AppRoleX.fromString(stats['role'] as String? ?? 'garson').labelTr;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Color based on name hash
    final avatarColors = [
      _orange,
      _blue,
      _green,
      const Color(0xFFAF52DE),
      const Color(0xFF30B0C7),
      const Color(0xFF5856D6),
    ];
    final avatarColor = avatarColors[
        name.codeUnits.fold(0, (a, b) => a + b) % avatarColors.length];

    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : _textSec;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: rank <= 3 ? medalColor : medalColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : medalColor,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('yönetici',
                            style: TextStyle(
                                fontSize: 10,
                                color: _orange,
                                fontWeight: FontWeight.w600)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (count > 0)
                      Text(
                        '$count işlem',
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                    if (count > 0 && lastSale != null)
                      Text(' · ',
                          style: TextStyle(fontSize: 12, color: _textSec)),
                    if (lastSale != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(lastSale),
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                  ],
                ),
                if (todayMinutes > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.clock_fill,
                          size: 11, color: _green),
                      const SizedBox(width: 3),
                      Text(
                        'Bugün: ${ShiftService.to.formatDuration(todayMinutes)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Revenue
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${SettingsService.cs}${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: _orange),
              ),
              Text('toplam', style: TextStyle(fontSize: 11, color: _textSec)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffRolePicker extends StatelessWidget {
  const _StaffRolePicker({
    required this.value,
    required this.onChanged,
  });

  final AppRole value;
  final ValueChanged<AppRole> onChanged;

  static const _options = [AppRole.admin, AppRole.staff, AppRole.kitchen];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rol',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in _options)
              ChoiceChip(
                label: Text(role.labelTr),
                selected: value == role,
                onSelected: (_) => onChanged(role),
                selectedColor: _orange.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value == role ? _orange : _textSec,
                ),
                side: BorderSide(
                  color:
                      value == role ? _orange.withValues(alpha: 0.45) : _border,
                ),
                backgroundColor: _bg,
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }
}
