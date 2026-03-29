import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/services/staff_service.dart';
import 'package:adisyos/services/day_service.dart';
import 'package:adisyos/views/auth_screen.dart';
import 'package:adisyos/views/home_view.dart';
import 'package:adisyos/views/tables_view.dart';

const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _separator   = Color(0xFFE5E5EA);
const _red         = Color(0xFFFF3B30);
const _green       = Color(0xFF34C759);

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  Map<String, dynamic>? _selectedStaff;
  String _enteredPin = '';
  bool _hasError = false;

  void _onStaffTap(Map<String, dynamic> staff) {
    setState(() {
      _selectedStaff = staff;
      _enteredPin = '';
      _hasError = false;
    });
  }

  void _onDigit(String d) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += d;
      _hasError = false;
    });
    if (_enteredPin.length == 4) _submitPin();
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  void _submitPin() {
    final staff = _selectedStaff;
    if (staff == null) return;
    if (StaffService.to.verifyPin(staff['id'] as String, _enteredPin)) {
      StaffService.to.setCurrentStaff(staff);
      Get.offAll(() => const TablesView());
    } else {
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });
    }
  }

  void _goBack() {
    setState(() {
      _selectedStaff = null;
      _enteredPin = '';
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _selectedStaff == null
            ? _StaffPicker(onStaffTap: _onStaffTap)
            : _PinPad(
                staff: _selectedStaff!,
                pin: _enteredPin,
                hasError: _hasError,
                onDigit: _onDigit,
                onDelete: _onDelete,
                onBack: _goBack,
              ),
      ),
    );
  }
}

// ── Staff Picker ───────────────────────────────────────────────

class _StaffPicker extends StatelessWidget {
  const _StaffPicker({required this.onStaffTap});
  final void Function(Map<String, dynamic>) onStaffTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Full-logout button — top right
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20, color: _textSec),
              tooltip: 'Hesaptan Çık',
              onPressed: () async {
                final email = AuthController.to.user.value?.email ?? '';
                if (email.isNotEmpty &&
                    DayService.to.isDayStartedBy(email)) {
                  await DayService.to.endDay(email);
                }
                StaffService.to.clearCurrentStaff();
                await AuthController.to.logout();
                Get.offAll(() => const AuthScreen());
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Brand
        Text(
          'adisyos',
          style: GoogleFonts.righteous(
            fontSize: 28,
            color: _orange,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kim giriş yapıyor?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Adınıza dokunun',
          style: TextStyle(fontSize: 14, color: _textSec),
        ),
        const SizedBox(height: 32),

        // Staff list
        Expanded(
          child: Obx(() {
            final staff = StaffService.to.staffList;
            if (staff.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_outline_rounded,
                          size: 36, color: _orange),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Henüz personel eklenmedi',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ayarlar\'dan personel ekleyebilirsiniz',
                      style: TextStyle(fontSize: 13, color: _textSec),
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: staff.length,
              itemBuilder: (_, i) => _StaffCard(
                staff: staff[i],
                onTap: () => onStaffTap(staff[i]),
              ),
            );
          }),
        ),

        // Manager button — only visible for admin accounts
        Obx(() {
          if (!AuthController.to.isAdmin) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: GestureDetector(
              onTap: () => Get.offAll(() => const HomeView()),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _separator),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 18, color: _textSec),
                    SizedBox(width: 8),
                    Text(
                      'Yönetici Girişi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSec,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StaffCard extends StatefulWidget {
  const _StaffCard({required this.staff, required this.onTap});
  final Map<String, dynamic> staff;
  final VoidCallback onTap;

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.staff['name'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    // Generate consistent color from name
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFFFF3B30),
      const Color(0xFF30B0C7),
      const Color(0xFF5856D6),
    ];
    final color = colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(color, Colors.white, 0.25)!,
                      color,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PIN Pad ────────────────────────────────────────────────────

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.staff,
    required this.pin,
    required this.hasError,
    required this.onDigit,
    required this.onDelete,
    required this.onBack,
  });

  final Map<String, dynamic> staff;
  final String pin;
  final bool hasError;
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final name = staff['name'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFFFF3B30),
      const Color(0xFF30B0C7),
      const Color(0xFF5856D6),
    ];
    final color = colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];

    return Column(
      children: [
        // Back + title
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: _textPrimary),
                onPressed: onBack,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Avatar
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.25)!,
                color,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasError ? 'Yanlış PIN, tekrar deneyin' : 'PIN kodunuzu girin',
          style: TextStyle(
            fontSize: 13,
            color: hasError ? _red : _textSec,
            fontWeight: hasError ? FontWeight.w600 : FontWeight.w400,
          ),
        ),

        const SizedBox(height: 28),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasError
                    ? _red
                    : filled
                        ? color
                        : _separator,
              ),
            );
          }),
        ),

        const Spacer(),

        // Number pad — fixed 300px wide, centered, never stretches on tablet
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Center(
            child: SizedBox(
              width: 300,
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) {
                          if (d.isEmpty) return const SizedBox(width: 80);
                          return _PinKey(
                            label: d,
                            onTap: d == '⌫' ? onDelete : () => onDigit(d),
                            isDelete: d == '⌫',
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinKey extends StatefulWidget {
  const _PinKey(
      {required this.label, required this.onTap, this.isDelete = false});
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isDelete ? _red.withOpacity(0.1) : _orange.withOpacity(0.1))
              : _card,
          shape: BoxShape.circle,
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
        ),
        child: Center(
          child: widget.isDelete
              ? Icon(Icons.backspace_outlined,
                  size: 22,
                  color: _pressed ? _red : _textSec)
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: _pressed ? _orange : _textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
