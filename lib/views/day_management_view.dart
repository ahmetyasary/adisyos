import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/day_service.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/settings_service.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _green       = Color(0xFF34C759);
const _red         = Color(0xFFFF3B30);
const _blue        = Color(0xFF007AFF);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

// ── Helpers ───────────────────────────────────────────────────

String _displayName(String? identifier) {
  if (identifier == null || identifier.trim().isEmpty) return 'Bilinmiyor';
  if (identifier.contains('@')) return 'Yönetici';
  return identifier;
}

String _formatDuration(DateTime start, DateTime? end) {
  final diff = (end ?? DateTime.now()).difference(start);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return h > 0 ? '${h}sa ${m}dk' : '${m}dk';
}

// ── View ──────────────────────────────────────────────────────

class DayManagementView extends StatelessWidget {
  const DayManagementView({super.key});

  /// Compute per-identifier sales totals from SalesHistoryService.
  /// Returns Map<displayName, {total, count}>.
  Map<String, Map<String, dynamic>> _salesByIdentifier() {
    final result = <String, Map<String, dynamic>>{};
    for (final sale in SalesHistoryService.to.sales) {
      final raw = sale['staffEmail'] as String? ?? '';
      final name = _displayName(raw.isEmpty ? null : raw);
      result.putIfAbsent(name, () => {'total': 0.0, 'count': 0});
      result[name]!['total'] =
          (result[name]!['total'] as double) + ((sale['total'] as num).toDouble());
      result[name]!['count'] = (result[name]!['count'] as int) + 1;
    }
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
                      onPressed: Get.back,
                    ),
                    const Text(
                      'Gün Yönetimi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ────────────────────────────────────
            Expanded(
              child: Obx(() {
                // touch all reactive sources
                DayService.to.allDays.length;
                SalesHistoryService.to.sales.length;

                final days = DayService.to.allDays;
                final salesMap = _salesByIdentifier();

                if (days.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.wb_sunny_rounded,
                              size: 40, color: _orange),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz gün kaydı yok',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Günler başlatıldığında burada görünecek.',
                          style: TextStyle(fontSize: 13, color: _textSec),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final d in days) {
                  final date = (d['day_date'] as String? ?? '').substring(0, 10);
                  grouped.putIfAbsent(date, () => []).add(d);
                }
                final sortedDates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: sortedDates.length,
                  itemBuilder: (_, i) {
                    final date = sortedDates[i];
                    final dayRecords = grouped[date]!;
                    return _DayGroup(
                      date: date,
                      records: dayRecords,
                      salesMap: salesMap,
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
}

// ── Day Group (one per calendar date) ────────────────────────

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.date,
    required this.records,
    required this.salesMap,
  });

  final String date;
  final List<Map<String, dynamic>> records;
  final Map<String, Map<String, dynamic>> salesMap;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final label = parsed != null
        ? DateFormat('dd MMMM yyyy, EEEE', 'tr').format(parsed)
        : date;

    final isToday = parsed != null &&
        parsed.year == DateTime.now().year &&
        parsed.month == DateTime.now().month &&
        parsed.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSec,
                  letterSpacing: 0.5,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BUGÜN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Session cards
        ...records.map((r) => _SessionCard(record: r, salesMap: salesMap)),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Session Card ──────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.record, required this.salesMap});

  final Map<String, dynamic> record;
  final Map<String, Map<String, dynamic>> salesMap;

  @override
  Widget build(BuildContext context) {
    final raw = record['started_by'] as String? ?? '';
    final displayName = _displayName(raw.isEmpty ? null : raw);
    final isAdmin = raw.contains('@');

    final startedAt = DateTime.tryParse(record['started_at'] as String? ?? '');
    final endedAt = record['ended_at'] != null
        ? DateTime.tryParse(record['ended_at'] as String)
        : null;
    final isActive = endedAt == null;

    final duration =
        startedAt != null ? _formatDuration(startedAt, endedAt) : '-';

    final salesData = salesMap[displayName];
    final salesTotal = salesData?['total'] as double? ?? 0.0;
    final salesCount = salesData?['count'] as int? ?? 0;

    // Avatar color from name hash
    final colors = [
      _orange, _blue, _green,
      const Color(0xFFAF52DE), const Color(0xFF30B0C7), const Color(0xFF5856D6),
    ];
    final avatarColor = colors[
        displayName.codeUnits.fold(0, (a, b) => a + b) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: isActive
            ? Border.all(color: _green.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 5,
              offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: avatar + name + status ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(avatarColor, Colors.white, 0.28)!,
                        avatarColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + role badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'yönetici',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive ? _green : _textSec,
                              shape: BoxShape.circle,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: _green.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Devam Ediyor' : 'Tamamlandı',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isActive ? _green : _textSec,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Duration pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _green.withValues(alpha: 0.1)
                        : _bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? _green : _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────
          const Divider(height: 1, color: _border),

          // ── Bottom row: time + sales ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                // Start time
                _InfoChip(
                  icon: Icons.login_rounded,
                  color: _green,
                  label: 'Başladı',
                  value: startedAt != null
                      ? DateFormat('HH:mm').format(startedAt)
                      : '-',
                ),
                const SizedBox(width: 12),

                // End time
                _InfoChip(
                  icon: Icons.logout_rounded,
                  color: isActive ? _textSec : _red,
                  label: 'Bitti',
                  value: endedAt != null
                      ? DateFormat('HH:mm').format(endedAt)
                      : '–',
                ),

                const Spacer(),

                // Sales summary
                if (salesCount > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Obx(() => Text(
                        '${SettingsService.cs}${salesTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _orange,
                        ),
                      )),
                      Text(
                        '$salesCount işlem',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSec,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Satış yok',
                    style: TextStyle(fontSize: 12, color: _textSec),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: _textSec)),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
