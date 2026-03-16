import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:adisyos/services/sales_history_service.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Colors.white;
const _orange = Color(0xFFF5A623);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec = Color(0xFF9B9B9B);

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
              color: _card,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _textPrimary),
                    onPressed: () => Get.back(),
                  ),
                  const Text(
                    'Personel Raporu',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _textPrimary),
                  ),
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
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: medalColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: medalColor,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                    color: _orange,
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
