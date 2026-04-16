import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/settings_service.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _green       = Color(0xFF34C759);
const _blue        = Color(0xFF007AFF);

class StaffReportView extends StatelessWidget {
  const StaffReportView({super.key});

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
    final sales    = SalesHistoryService.to.sales;
    final shifts   = ShiftService.to.shifts;
    final today    = DateTime.now();

    // Aggregate sales — all admin/email/unknown entries merge into _adminKey
    final Map<String, Map<String, dynamic>> salesMap = {};
    for (final sale in sales) {
      final id = _toKey(sale['staffEmail'] as String?);
      salesMap.putIfAbsent(id, () => {'total': 0.0, 'count': 0, 'lastSale': null});
      salesMap[id]!['total'] =
          (salesMap[id]!['total'] as double) + ((sale['total'] as num).toDouble());
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
      hoursMap[id] = (hoursMap[id] ?? 0) + ShiftService.to.getWorkMinutes(shift);
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
        'isAdmin': true,
        'total': s['total'] as double,
        'count': s['count'] as int,
        'lastSale': s['lastSale'] as DateTime?,
        'todayMinutes': 0,
      });
    }

    result.sort(
        (a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: const BoxDecoration(
                color: _card,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 16,
                      offset: Offset(0, 2)),
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
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: _textSec),
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
                  itemBuilder: (_, i) =>
                      _StaffCard(stats: stats[i], rank: i + 1),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.stats, required this.rank});

  final Map<String, dynamic> stats;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final name         = stats['name'] as String;
    final total        = stats['total'] as double;
    final count        = stats['count'] as int;
    final lastSale     = stats['lastSale'] as DateTime?;
    final todayMinutes = stats['todayMinutes'] as int;
    final isAdmin      = stats['isAdmin'] as bool? ?? false;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Color based on name hash
    final avatarColors = [
      _orange, _blue, _green,
      const Color(0xFFAF52DE), const Color(0xFF30B0C7), const Color(0xFF5856D6),
    ];
    final avatarColor =
        avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % avatarColors.length];

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
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(18)),
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
              gradient: rank <= 3
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(medalColor, Colors.white, 0.28)!,
                        medalColor
                      ],
                    )
                  : null,
              color: rank > 3 ? medalColor.withOpacity(0.12) : null,
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(avatarColor, Colors.white, 0.28)!,
                  avatarColor
                ],
              ),
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
                        style: const TextStyle(
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
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (count > 0)
                      Text(
                        '$count işlem',
                        style: const TextStyle(fontSize: 12, color: _textSec),
                      ),
                    if (count > 0 && lastSale != null)
                      const Text(' · ',
                          style:
                              TextStyle(fontSize: 12, color: _textSec)),
                    if (lastSale != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(lastSale),
                        style: const TextStyle(
                            fontSize: 12, color: _textSec),
                      ),
                  ],
                ),
                if (todayMinutes > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _orange),
              ),
              const Text('toplam',
                  style: TextStyle(fontSize: 11, color: _textSec)),
            ],
          ),
        ],
      ),
    );
  }
}
