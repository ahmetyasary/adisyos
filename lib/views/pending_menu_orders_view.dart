import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/services/digital_menu_order_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/shell_leading.dart';

const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFE5E5EA);
const _green = Color(0xFF34C759);
const _red = Color(0xFFFF3B30);

class PendingMenuOrdersView extends StatelessWidget {
  const PendingMenuOrdersView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final svc = DigitalMenuOrderService.to;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  ShellLeading(embedded: embedded, color: _textPrimary),
                  const Expanded(
                    child: Text(
                      'Bekleyen siparişler',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: svc.refresh,
                    icon: const Icon(CupertinoIcons.arrow_clockwise,
                        color: _textSec),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (svc.loading.value && svc.pending.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: _orange),
                );
              }
              final list = svc.pending.toList();
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal,
                            size: 48, color: _textSec),
                        SizedBox(height: 12),
                        Text(
                          'Bekleyen sipariş yok',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Müşteriler masa QR menüsünden sipariş gönderince burada görünür.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _textSec),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _OrderCard(order: list[i]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final svc = DigitalMenuOrderService.to;
    final cs = SettingsService.cs;
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final note = (order['note'] as String?)?.trim() ?? '';
    final occupied = svc.isTableOccupied(order['tableId'] as int);
    final created = DateTime.tryParse(order['createdAt'] as String? ?? '');
    final timeLabel = created == null
        ? ''
        : DateFormat('HH:mm').format(created.toLocal());
    final total = items.fold<double>(
      0,
      (s, it) =>
          s +
          ((it['price'] as num?)?.toDouble() ?? 0) *
              ((it['qty'] as num?)?.toInt() ?? 1),
    );

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order['tableName'] as String? ?? 'Masa',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (timeLabel.isNotEmpty)
                Text(timeLabel,
                    style: const TextStyle(fontSize: 12, color: _textSec)),
            ],
          ),
          if (occupied) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Masa dolu — onaylamadan önce uyarı gösterilir.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A5B00),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...items.map((it) {
            final qty = (it['qty'] as num?)?.toInt() ?? 1;
            final price = (it['price'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$qty×  ${it['name']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$cs${(price * qty).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textSec,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.chat_bubble_text,
                      size: 16, color: _orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Toplam $cs${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final msg = await svc.reject(order['id'] as String);
                  if (msg != null) AppToast.info(msg);
                },
                child: const Text('Reddet',
                    style: TextStyle(
                        color: _red, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final msg = await svc.approve(order['id'] as String);
                  if (msg != null) AppToast.success(msg);
                },
                child: const Text('Onayla',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
