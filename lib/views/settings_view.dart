import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/services/settings_service.dart';
import 'package:adisyos/services/staff_service.dart';
import 'package:adisyos/services/section_service.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'package:adisyos/widgets/app_toast.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

// ──────────────────────────────────────────────────────────────
// SettingsView
// ──────────────────────────────────────────────────────────────

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _companyCtrl = TextEditingController();
  String _selectedLanguage = 'tr';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from already-loaded value
    _companyCtrl.text = SettingsService.to.companyName.value;

    // If service is still loading, sync when it arrives
    ever(SettingsService.to.companyName, (val) {
      if (mounted && _companyCtrl.text.isEmpty && val.isNotEmpty) {
        _companyCtrl.text = val;
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _selectedLanguage =
              prefs.getString('language') ?? (Get.locale?.languageCode ?? 'tr');
        });
      }
    });
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SettingsService.to.save(newCompanyName: _companyCtrl.text.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selectedLanguage);
    setState(() => _saving = false);
    if (mounted) {
      AppToast.success('Ayarlar kaydedildi', title: 'success'.tr);
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            _Header(),

            // ── Scrollable content ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Account card
                    _AccountCard(),
                    const SizedBox(height: 28),

                    // Business section
                    _SectionLabel('İşletme'),
                    const SizedBox(height: 10),
                    _Card(
                      child: _InlineField(
                        icon: Icons.store_rounded,
                        label: 'Şirket Adı',
                        hint: 'Şirket adınızı girin',
                        controller: _companyCtrl,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Staff section
                    _SectionLabel('Personel'),
                    const SizedBox(height: 10),
                    _StaffManagementCard(),
                    const SizedBox(height: 28),

                    // Sections (floor areas)
                    _SectionLabel('Bölümler'),
                    const SizedBox(height: 10),
                    _SectionsCard(),
                    const SizedBox(height: 28),

                    // Language section
                    _SectionLabel('Dil'),
                    const SizedBox(height: 10),
                    _Card(
                      child: _LanguageRow(
                        value: _selectedLanguage,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedLanguage = val);
                          Get.updateLocale(val == 'tr'
                              ? const Locale('tr', 'TR')
                              : const Locale('en', 'US'));
                        },
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save button
                    _SaveButton(saving: _saving, onTap: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _Header
// ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _textPrimary),
            onPressed: () => Get.back(),
          ),
          Text(
            'settings'.tr,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _AccountCard — shows logged-in user info
// ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user      = AuthController.to.user.value;
      final email     = user?.email ?? '';
      final roleLabel = user?.role.name ?? '';
      final initial   = email.isNotEmpty ? email[0].toUpperCase() : 'U';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB340), Color(0xFFFF9500)],
                ),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3DFF9500),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.split('@').first,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSec,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ──────────────────────────────────────────────────────────────
// Small helpers
// ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSec,
        letterSpacing: 1,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

// ── Inline text field row ──────────────────────────────────────

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  textCapitalization: textCapitalization,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: _textSec, fontSize: 14),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
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

// ── Language row ───────────────────────────────────────────────

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onChanged});

  final String value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.language_rounded, size: 17, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dil',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                    icon: const Icon(Icons.expand_more_rounded,
                        size: 18, color: _textSec),
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: onChanged,
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

// ── Staff Management Card ──────────────────────────────────────

class _StaffManagementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final staffList = StaffService.to.staffList;
      return _Card(
        child: Column(
          children: [
            ...staffList.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
                  _StaffRow(staff: s),
                ],
              );
            }),
            if (staffList.isNotEmpty)
              const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
            // Add staff button row
            GestureDetector(
              onTap: () => _showAddStaffDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.person_add_rounded, size: 17, color: _orange),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Personel Ekle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final pinCtrl  = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('Personel Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinCtrl,
            decoration: const InputDecoration(
              labelText: '4 Haneli PIN',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final pin  = pinCtrl.text.trim();
            if (name.isEmpty || pin.length != 4) return;
            await StaffService.to.addStaff(name, pin);
            Get.back();
          },
          child: const Text('Ekle'),
        ),
      ],
    ));
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.staff});
  final Map<String, dynamic> staff;

  @override
  Widget build(BuildContext context) {
    final name    = staff['name'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _orange,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary)),
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: _textSec),
            onPressed: () => _showEditDialog(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF3B30)),
            onPressed: () => _confirmDelete(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: staff['name'] as String);
    final pinCtrl  = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('Personeli Düzenle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinCtrl,
            decoration: const InputDecoration(
              labelText: 'Yeni PIN (boş bırakın = değişmesin)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final pin  = pinCtrl.text.trim().isEmpty
                ? staff['pin'] as String
                : pinCtrl.text.trim();
            if (name.isEmpty) return;
            await StaffService.to.updateStaff(
              staff['id'] as String,
              name: name,
              pin: pin,
            );
            Get.back();
          },
          child: const Text('Kaydet'),
        ),
      ],
    ));
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(AlertDialog(
      title: const Text('Personeli Sil'),
      content: Text('${staff['name']} silinsin mi?'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await StaffService.to.deleteStaff(staff['id'] as String);
            Get.back();
          },
          child: const Text('Sil'),
        ),
      ],
    ));
  }
}

// ── Sections Card ──────────────────────────────────────────────

class _SectionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sections = SectionService.to.sections;
      return _Card(
        child: Column(
          children: [
            ...sections.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
                  _SectionRow(section: s),
                ],
              );
            }),
            if (sections.isNotEmpty)
              const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
            GestureDetector(
              onTap: () => _showAddDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.add_rounded, size: 17, color: _orange),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Bölüm Ekle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showAddDialog(BuildContext context) {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('Bölüm Ekle'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(
          labelText: 'Bölüm Adı (örn: İç Alan, Bahçe)',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            await SectionService.to.addSection(ctrl.text.trim());
            Get.back();
          },
          child: const Text('Ekle'),
        ),
      ],
    ));
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final name = section['name'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.grid_view_rounded, size: 16, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: _textSec),
            onPressed: () => _showEditDialog(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: Color(0xFFFF3B30)),
            onPressed: () => _confirmDelete(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: section['name'] as String);
    Get.dialog(AlertDialog(
      title: const Text('Bölümü Düzenle'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(
          labelText: 'Bölüm Adı',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            await SectionService.to.updateSection(
                section['id'] as String, ctrl.text.trim());
            Get.back();
          },
          child: const Text('Kaydet'),
        ),
      ],
    ));
  }

  void _confirmDelete() {
    Get.dialog(AlertDialog(
      title: const Text('Bölümü Sil'),
      content: Text('"${section['name']}" silinsin mi?'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('İptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await SectionService.to.deleteSection(section['id'] as String);
            Get.back();
          },
          child: const Text('Sil'),
        ),
      ],
    ));
  }
}

// ── Save button ────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB340), _orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44FF9500),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: saving ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'save_settings'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
