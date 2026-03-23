import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);

class StaffReportView extends StatelessWidget {
  const StaffReportView({super.key});

  Map<String, Map<String, dynamic>> _buildStaffStats() {
    final sales = SalesHistoryService.to.sales;
    final Map<String, Map<String, dynamic>> stats = {};

    for (final sale in sales) {
      final email = (sale['staffEmail'] as String? ?? '').isEmpty
          ? 'Bilinmiyor'
          : sale['staffEmail'] as String;

      if (!stats.containsKey(email)) {
        stats[email] = {
          'email': email,
          'total': 0.0,
          'count': 0,
          'lastSale': sale['date'] as String,
        };
      }

      stats[email]!['total'] =
          (stats[email]!['total'] as double) + ((sale['total'] as num).toDouble());
      stats[email]!['count'] = (stats[email]!['count'] as int) + 1;

      final saleDate = DateTime.parse(sale['date'] as String);
      final lastDate = DateTime.parse(stats[email]!['lastSale'] as String);
      if (saleDate.isAfter(lastDate)) {
        stats[email]!['lastSale'] = sale['date'] as String;
      }
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: _card,
                boxShadow: [
                  BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
                  BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
                ],
              ),
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
            Expanded(
              child: Obx(() {
                final stats = _buildStaffStats();
                if (stats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 48, color: _textSec),
                        const SizedBox(height: 12),
                        const Text(
                          'Henüz satış verisi yok',
                          style: TextStyle(color: _textSec, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = stats.values.toList()
                  ..sort((a, b) => (b['total'] as double)
                      .compareTo(a['total'] as double));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) =>
                      _StaffCard(staff: sorted[i], rank: i + 1),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Staff Card ───────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff, required this.rank});

  final Map<String, dynamic> staff;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final email = staff['email'] as String;
    final total = staff['total'] as double;
    final count = staff['count'] as int;
    final lastSale = DateTime.tryParse(staff['lastSale'] as String);
    final initial =
        (email != 'Bilinmiyor' && email.isNotEmpty) ? email[0].toUpperCase() : '?';

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
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: rank <= 3
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(medalColor, Colors.white, 0.28)!, medalColor],
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
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(_orange, Colors.white, 0.28)!, _orange],
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
                initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email == 'Bilinmiyor'
                      ? email
                      : email.split('@').first,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$count işlem · ${lastSale != null ? DateFormat('dd/MM/yyyy').format(lastSale) : '-'}',
                  style: const TextStyle(fontSize: 12, color: _textSec),
                ),
              ],
            ),
          ),
          // Revenue
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₺${total.toStringAsFixed(2)}',
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
