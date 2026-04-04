import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/shift_service.dart';
import 'package:adisyos/services/staff_service.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _orangeLight = Color(0xFFFFF4E0);
const _green       = Color(0xFF34C759);
const _greenLight  = Color(0xFFE8FAF0);
const _red         = Color(0xFFFF3B30);
const _blue        = Color(0xFF007AFF);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

class ShiftManagementView extends StatefulWidget {
  const ShiftManagementView({super.key});

  @override
  State<ShiftManagementView> createState() => _ShiftManagementViewState();
}

class _ShiftManagementViewState extends State<ShiftManagementView> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String get _email => StaffService.to.currentStaffIdentifier.isNotEmpty
      ? StaffService.to.currentStaffIdentifier
      : AuthController.to.user.value?.email ?? '';
  AppRole? get _role => AuthController.to.currentRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: Obx(() {
                final isClockedIn = ShiftService.to.isClockedIn(_email);
                final isOnBreak = ShiftService.to.isOnBreak(_email);
                final activeShift = ShiftService.to.getActiveShift(_email);
                final todayShifts =
                    ShiftService.to.getShiftsForDate(DateTime.now());

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current user status card
                      _MyShiftCard(
                        email: _email,
                        isClockedIn: isClockedIn,
                        isOnBreak: isOnBreak,
                        activeShift: activeShift,
                        now: _now,
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      _ActionRow(
                        isClockedIn: isClockedIn,
                        isOnBreak: isOnBreak,
                        email: _email,
                      ),

                      // Admin: today's all shifts
                      if (_role == AppRole.admin && todayShifts.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionLabel(
                          icon: Icons.today_rounded,
                          title: 'Bugünkü Vardiyalar',
                        ),
                        const SizedBox(height: 12),
                        ...todayShifts.map((s) => _ShiftRow(shift: s)),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _textPrimary),
              onPressed: () => Get.back(),
            ),
            const Text(
              'Vardiya Yönetimi',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: -0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── My Shift Card ────────────────────────────────────────────

class _MyShiftCard extends StatelessWidget {
  const _MyShiftCard({
    required this.email,
    required this.isClockedIn,
    required this.isOnBreak,
    required this.activeShift,
    required this.now,
  });

  final String email;
  final bool isClockedIn;
  final bool isOnBreak;
  final Map<String, dynamic>? activeShift;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final statusColor = isClockedIn
        ? (isOnBreak ? _orange : _green)
        : _textSec;
    final statusBg = isClockedIn
        ? (isOnBreak ? _orangeLight : _greenLight)
        : const Color(0xFFF5F5F5);
    final statusLabel = isClockedIn
        ? (isOnBreak ? 'Molada' : 'Vardiyada')
        : 'Dışarıda';

    String workTime = '-';
    String breakTime = '-';
    String startTimeStr = '-';

    if (activeShift != null) {
      workTime = ShiftService.to
          .formatDuration(ShiftService.to.getWorkMinutes(activeShift!));
      breakTime = ShiftService.to
          .formatDuration(ShiftService.to.getBreakMinutes(activeShift!));
      startTimeStr = DateFormat('HH:mm').format(
          DateTime.parse(activeShift!['startTime'] as String));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6)),
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFBF4D), _orange],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email.split('@').first,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(email,
                        style:
                            const TextStyle(fontSize: 12, color: _textSec)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          if (isClockedIn) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ShiftStat(
                      label: 'Başlangıç',
                      value: startTimeStr,
                      icon: Icons.login_rounded,
                      color: _green),
                ),
                Expanded(
                  child: _ShiftStat(
                      label: 'Çalışma',
                      value: workTime,
                      icon: Icons.timer_rounded,
                      color: _blue),
                ),
                Expanded(
                  child: _ShiftStat(
                      label: 'Mola',
                      value: breakTime,
                      icon: Icons.coffee_rounded,
                      color: _orange),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftStat extends StatelessWidget {
  const _ShiftStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _textPrimary)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: _textSec)),
      ],
    );
  }
}

// ── Action Row ──────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isClockedIn,
    required this.isOnBreak,
    required this.email,
  });

  final bool isClockedIn;
  final bool isOnBreak;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigBtn(
            label: isClockedIn ? 'Çıkış Yap' : 'Giriş Yap',
            icon: isClockedIn ? Icons.logout_rounded : Icons.login_rounded,
            color: isClockedIn ? _red : _green,
            onTap: () {
              if (isClockedIn) {
                ShiftService.to.clockOut(email);
              } else {
                ShiftService.to.clockIn(email);
              }
            },
          ),
        ),
        if (isClockedIn) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _BigBtn(
              label: isOnBreak ? 'Molayı Bitir' : 'Mola Başlat',
              icon: isOnBreak
                  ? Icons.play_arrow_rounded
                  : Icons.coffee_rounded,
              color: _orange,
              onTap: () {
                if (isOnBreak) {
                  ShiftService.to.endBreak(email);
                } else {
                  ShiftService.to.startBreak(email);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.2),
        ),
      ],
    );
  }
}

// ── Shift Row (admin list) ───────────────────────────────────

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift});
  final Map<String, dynamic> shift;

  @override
  Widget build(BuildContext context) {
    final staffEmail = shift['staffEmail'] as String;
    final start = DateTime.parse(shift['startTime'] as String);
    final endStr = shift['endTime'] as String?;
    final end = endStr != null ? DateTime.parse(endStr) : null;
    final isActive = end == null;

    final workMins = ShiftService.to.getWorkMinutes(shift);
    final breakMins = ShiftService.to.getBreakMinutes(shift);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 3)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [Color.lerp(_green, Colors.white, 0.28)!, _green]
                    : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                staffEmail.isNotEmpty ? staffEmail[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staffEmail.split('@').first,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('HH:mm').format(start)} → '
                  '${end != null ? DateFormat('HH:mm').format(end) : 'devam ediyor'}',
                  style: const TextStyle(fontSize: 12, color: _textSec),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ShiftService.to.formatDuration(workMins),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _textPrimary),
              ),
              if (breakMins > 0)
                Text(
                  'Mola: ${ShiftService.to.formatDuration(breakMins)}',
                  style:
                      const TextStyle(fontSize: 11, color: _textSec),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
