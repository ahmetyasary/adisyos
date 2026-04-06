import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/kitchen_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/services/section_service.dart';

// ── Design tokens ──────────────────────────────────────────────
const _bg           = Color(0xFFF2F2F7);
const _card         = Colors.white;
const _textPrimary  = Color(0xFF1C1C1E);
const _textSec      = Color(0xFF8E8E93);
const _colPending   = Color(0xFFFF9500);
const _colPreparing = Color(0xFF007AFF);
const _colReady     = Color(0xFF34C759);

class KitchenDisplayView extends StatefulWidget {
  const KitchenDisplayView({super.key});

  @override
  State<KitchenDisplayView> createState() => _KitchenDisplayViewState();
}

class _KitchenDisplayViewState extends State<KitchenDisplayView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            return Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(
                  child: Obx(() {
                    final svc = KitchenService.to;
                    return isMobile
                        ? _buildMobileLayout(svc)
                        : _buildTabletLayout(svc);
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
          // Mobile: show TabBar inside header
          if (isMobile)
            Obx(() {
              final svc = KitchenService.to;
              return TabBar(
                controller: _tabController,
                indicatorColor: _textPrimary,
                indicatorWeight: 2,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  _StatusTab(label: 'Bekliyor',    color: _colPending,   count: svc.pendingTickets.length),
                  _StatusTab(label: 'Hazırlanıyor',color: _colPreparing, count: svc.preparingTickets.length),
                  _StatusTab(label: 'Hazır',       color: _colReady,     count: svc.readyTickets.length),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ── Mobile: TabBarView ─────────────────────────────────────────
  Widget _buildMobileLayout(KitchenService svc) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return TabBarView(
      controller: _tabController,
      children: [
        _KitchenList(
          color: _colPending,
          tickets: svc.pendingTickets,
          nextLabel: 'Hazırlamaya Başla',
          onAdvance: (id) => svc.advanceStatus(id),
          bottomPad: bottomPad,
        ),
        _KitchenList(
          color: _colPreparing,
          tickets: svc.preparingTickets,
          nextLabel: 'Hazır',
          onAdvance: (id) => svc.advanceStatus(id),
          bottomPad: bottomPad,
        ),
        _KitchenList(
          color: _colReady,
          tickets: svc.readyTickets,
          nextLabel: '',
          onAdvance: (_) {},
          showClearButton: true,
          bottomPad: bottomPad,
        ),
      ],
    );
  }

  // ── Tablet: 3-column grid ──────────────────────────────────────
  Widget _buildTabletLayout(KitchenService svc) {
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
            onAdvance: (_) {},
            showClearButton: true,
          ),
        ),
      ],
    );
  }
}

// ─── Tab indicator widget ──────────────────────────────────────
class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.color,
    required this.count,
  });

  final String label;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile: full-width scrollable list ───────────────────────
class _KitchenList extends StatelessWidget {
  const _KitchenList({
    required this.color,
    required this.tickets,
    required this.nextLabel,
    required this.onAdvance,
    this.showClearButton = false,
    this.bottomPad = 0,
  });

  final Color color;
  final List<Map<String, dynamic>> tickets;
  final String nextLabel;
  final void Function(String id) onAdvance;
  final bool showClearButton;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: color.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Boş',
              style: TextStyle(color: color.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (showClearButton && tickets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => KitchenService.to.clearReadyTickets(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('Temizle', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPad),
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
    );
  }
}

// ─── Tablet: styled column with tinted background ─────────────
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${tickets.length}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                if (showClearButton && tickets.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => KitchenService.to.clearReadyTickets(),
                    child: const Icon(Icons.clear_all, size: 18, color: _textSec),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: tickets.isEmpty
                ? Center(
                    child: Text('Boş',
                        style: TextStyle(
                            color: color.withOpacity(0.4), fontSize: 13)),
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

// ─── Ticket Card (shared) ──────────────────────────────────────
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

  /// Returns "Section · TableName" when the table has a section, else just TableName.
  String _resolveTableLabel(String rawName) {
    final tables = TableService.to.tables;
    final match = tables.firstWhereOrNull(
        (t) => (t['name'] as String) == rawName);
    if (match == null) return rawName;
    final sectionId = match['sectionId'] as String?;
    final sectionName = SectionService.to.nameById(sectionId);
    if (sectionName != null && sectionName.isNotEmpty) {
      return '$sectionName · $rawName';
    }
    return rawName;
  }

  @override
  Widget build(BuildContext context) {
    final tableLabel = _resolveTableLabel(ticket['tableName'] as String);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tableLabel,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 11),
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
                fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ticket['quantity']}x',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      fontSize: 14),
                ),
              ),
              if (nextLabel.isNotEmpty)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      nextLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
