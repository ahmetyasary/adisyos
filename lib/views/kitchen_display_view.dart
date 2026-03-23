import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/kitchen_service.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg           = Color(0xFFF2F2F7);
const _card         = Colors.white;
const _textPrimary  = Color(0xFF1C1C1E);
const _textSec      = Color(0xFF8E8E93);
const _border       = Color(0xFFE5E5EA);
const _colPending   = Color(0xFFFF9500);
const _colPreparing = Color(0xFF007AFF);
const _colReady     = Color(0xFF34C759);

class KitchenDisplayView extends StatelessWidget {
  const KitchenDisplayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Obx(() {
                final svc = KitchenService.to;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _KitchenColumn(
                        title: 'Bekliyor',
                        color: _colPending,
                        tickets: svc.pendingTickets,
                        nextLabel: 'Hazırlamaya Başla',
                        onAdvance: (id) => svc.advanceStatus(id),
                      ),
                    ),
                    Expanded(
                      child: _KitchenColumn(
                        title: 'Hazırlanıyor',
                        color: _colPreparing,
                        tickets: svc.preparingTickets,
                        nextLabel: 'Hazır',
                        onAdvance: (id) => svc.advanceStatus(id),
                      ),
                    ),
                    Expanded(
                      child: _KitchenColumn(
                        title: 'Hazır',
                        color: _colReady,
                        tickets: svc.readyTickets,
                        nextLabel: '',
                        onAdvance: (id) {},
                        showClearButton: true,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            'Mutfak Ekranı',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Obx(() {
            final pending = KitchenService.to.pendingTickets.length;
            if (pending == 0) return const SizedBox();
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _colPending.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$pending bekliyor',
                style: const TextStyle(
                    color: _colPending,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Column ───────────────────────────────────────────────────────────────────

class _KitchenColumn extends StatelessWidget {
  const _KitchenColumn({
    required this.title,
    required this.color,
    required this.tickets,
    required this.nextLabel,
    required this.onAdvance,
    this.showClearButton = false,
  });

  final String title;
  final Color color;
  final List<Map<String, dynamic>> tickets;
  final String nextLabel;
  final void Function(String id) onAdvance;
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tickets.length}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                if (showClearButton && tickets.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => KitchenService.to.clearReadyTickets(),
                    child: const Icon(Icons.clear_all,
                        size: 18, color: _textSec),
                  ),
                ],
              ],
            ),
          ),
          // Tickets
          Expanded(
            child: tickets.isEmpty
                ? Center(
                    child: Text(
                      'Boş',
                      style: TextStyle(
                          color: color.withOpacity(0.4), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: tickets.length,
                    itemBuilder: (context, i) => _TicketCard(
                      ticket: tickets[i],
                      color: color,
                      nextLabel: nextLabel,
                      onTap: () => onAdvance(tickets[i]['id'] as String),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.color,
    required this.nextLabel,
    required this.onTap,
  });

  final Map<String, dynamic> ticket;
  final Color color;
  final String nextLabel;
  final VoidCallback onTap;

  String _timeAgo(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    return '${diff.inHours} sa';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 3)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket['tableName'] as String,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
              Text(
                _timeAgo(ticket['orderedAt'] as String),
                style: const TextStyle(color: _textSec, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket['itemName'] as String,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ticket['quantity']}x',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      fontSize: 13),
                ),
              ),
              if (nextLabel.isNotEmpty)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      nextLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
