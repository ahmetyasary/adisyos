import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:orderix/models/payment_type.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';

Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.border;
const _orange = Color(0xFFFF9500);

class CompletedPaymentsView extends StatefulWidget {
  const CompletedPaymentsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CompletedPaymentsView> createState() => _CompletedPaymentsViewState();
}

class _CompletedPaymentsViewState extends State<CompletedPaymentsView> {
  @override
  void initState() {
    super.initState();
    SalesHistoryService.to.refresh();
  }

  Future<void> _editSale(Map<String, dynamic> sale) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSaleSheet(sale: sale),
    );
    if (changed == true && mounted) {
      AppToast.success('Ödeme güncellendi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
            decoration: BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  ShellLeading(
                    embedded: widget.embedded,
                    color: _textPrimary,
                  ),
                  Text(
                    'Tamamlanan ödemeler',
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
          Expanded(
            child: Obx(() {
              final service = SalesHistoryService.to;
              final recent = service.getRecentSales(limit: 20);
              if (service.loading.value && recent.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: _orange),
                );
              }
              if (recent.isEmpty) {
                return Center(
                  child: Text(
                    'Henüz tamamlanan ödeme yok.',
                    style: TextStyle(color: _textSec, fontSize: 14),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Son 20 ödeme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textSec,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: _border),
                              _CompletedPaymentTile(
                                sale: recent[i],
                                onEdit: () => _editSale(recent[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ödeme tipini, ürünleri ve fiyatları düzenleyebilirsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CompletedPaymentTile extends StatelessWidget {
  const _CompletedPaymentTile({
    required this.sale,
    required this.onEdit,
  });

  final Map<String, dynamic> sale;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(sale['date'] as String);
    final method = (sale['paymentMethod'] as String?) ?? 'cash';
    final baseMethod = SettingsService.to.paymentMethodBaseId(method);
    final (icon, iconColor) = paymentTypeVisual(baseMethod);
    final label = SettingsService.to.paymentMethodLabel(method);
    final total = (sale['total'] as num).toDouble();
    final table = (sale['tableName'] as String?)?.trim();
    final items = (sale['items'] as List?)?.length ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  DateFormat('HH:mm').format(date),
                  style: TextStyle(
                    color: _textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table?.isNotEmpty == true ? table! : 'Masa —',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(icon, size: 14, color: iconColor),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$label · $items ürün',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: _textSec),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${SettingsService.cs}${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF34C759),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: 'Düzenle',
                onPressed: onEdit,
                icon: Icon(CupertinoIcons.pencil, size: 18, color: _orange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditSaleSheet extends StatefulWidget {
  const _EditSaleSheet({required this.sale});

  final Map<String, dynamic> sale;

  @override
  State<_EditSaleSheet> createState() => _EditSaleSheetState();
}

class _EditSaleSheetState extends State<_EditSaleSheet> {
  late final List<_SaleItemDraft> _items;
  late String _paymentMethod;
  late bool _isCariPayment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final storedMethod =
        (widget.sale['paymentMethod'] as String?)?.trim() ?? '';
    _isCariPayment = storedMethod.startsWith('cari_');
    _paymentMethod = storedMethod.isNotEmpty
        ? SettingsService.to.paymentMethodBaseId(storedMethod)
        : 'cash';
    _items = [
      for (final raw in (widget.sale['items'] as List? ?? const []))
        _SaleItemDraft.fromMap((raw as Map).cast<String, dynamic>()),
    ];
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  List<PaymentType> get _paymentTypes {
    final types = SettingsService.to.paymentTypes.toList();
    if (types.any((type) => type.id == _paymentMethod)) return types;
    return [
      PaymentType(id: _paymentMethod, name: _paymentMethod),
      ...types,
    ];
  }

  double get _subtotal => _items.fold(0, (sum, item) {
        final qty = int.tryParse(item.quantity.text) ?? 0;
        final price =
            double.tryParse(item.price.text.replaceAll(',', '.')) ?? 0;
        return sum + (qty > 0 ? qty : 0) * (price >= 0 ? price : 0);
      });

  void _addItem() {
    setState(() => _items.add(_SaleItemDraft()));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final items = [
      for (final item in _items)
        {
          'name': item.name.text,
          'quantity': int.tryParse(item.quantity.text) ?? 0,
          'price': double.tryParse(item.price.text.replaceAll(',', '.')) ?? -1,
        },
    ];
    final ok = await SalesHistoryService.to.updateSale(
      saleId: widget.sale['id'] as String,
      items: items,
      paymentMethod: _isCariPayment ? 'cari_$_paymentMethod' : _paymentMethod,
      discount: (widget.sale['discount'] as num?)?.toDouble() ?? 0,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      AppToast.error('Ödeme güncellenemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _subtotal -
        ((widget.sale['discount'] as num?)?.toDouble() ?? 0)
            .clamp(0, _subtotal)
            .toDouble();
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ödemeyi düzenle',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ürün ve ödeme bilgilerini güncelleyin.',
              style: TextStyle(color: _textSec, fontSize: 13),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                labelText: 'Ödeme tipi',
                labelStyle: TextStyle(color: _textSec),
                filled: true,
                fillColor: AppColors.chipBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
              ),
              dropdownColor: _card,
              style: TextStyle(color: _textPrimary, fontSize: 14),
              items: [
                for (final type in _paymentTypes)
                  DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ürünler',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _addItem,
                  icon: const Icon(CupertinoIcons.plus, size: 16),
                  label: const Text('Ürün ekle'),
                  style: TextButton.styleFrom(foregroundColor: _orange),
                ),
              ],
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Ürün yok. Yeni ürün ekleyebilirsiniz.',
                  style: TextStyle(color: _textSec, fontSize: 13),
                ),
              ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SaleItemEditor(
                  draft: _items[i],
                  enabled: !_saving,
                  onChanged: () => setState(() {}),
                  onDelete: () => setState(() {
                    final removed = _items.removeAt(i);
                    removed.dispose();
                  }),
                ),
              ),
            Divider(color: _border, height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Yeni toplam',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${SettingsService.cs}${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF34C759),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : const Text(
                        'Değişiklikleri kaydet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleItemDraft {
  _SaleItemDraft({
    String name = '',
    String quantity = '1',
    String price = '0',
  })  : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity),
        price = TextEditingController(text: price);

  factory _SaleItemDraft.fromMap(Map<String, dynamic> item) {
    return _SaleItemDraft(
      name: item['name'] as String? ?? '',
      quantity: '${(item['quantity'] as num?)?.toInt() ?? 1}',
      price: ((item['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
  }

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class _SaleItemEditor extends StatelessWidget {
  const _SaleItemEditor({
    required this.draft,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
  });

  final _SaleItemDraft draft;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textSec, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: AppColors.chipBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: draft.name,
            enabled: enabled,
            style: TextStyle(color: _textPrimary, fontSize: 13),
            decoration: _decoration('Ürün'),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 58,
          child: TextField(
            controller: draft.quantity,
            enabled: enabled,
            keyboardType: TextInputType.number,
            style: TextStyle(color: _textPrimary, fontSize: 13),
            decoration: _decoration('Adet'),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 86,
          child: TextField(
            controller: draft.price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _textPrimary, fontSize: 13),
            decoration: _decoration('Fiyat'),
            onChanged: (_) => onChanged(),
          ),
        ),
        IconButton(
          tooltip: 'Ürünü kaldır',
          onPressed: enabled ? onDelete : null,
          padding: const EdgeInsets.only(left: 6, top: 8),
          constraints: const BoxConstraints(minWidth: 30, minHeight: 44),
          icon: const Icon(
            CupertinoIcons.minus_circle,
            color: Color(0xFFFF3B30),
            size: 19,
          ),
        ),
      ],
    );
  }
}
