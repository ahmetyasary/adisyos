import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/services/cari_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';
import 'package:orderix/widgets/shell_leading.dart';

Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
Color get _textPrimary => AppColors.textPrimary;
Color get _textSecondary => AppColors.textSec;
Color get _border => AppColors.border;
const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);
const _red = Color(0xFFFF3B30);

class CariAccountsView extends StatefulWidget {
  const CariAccountsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CariAccountsView> createState() => _CariAccountsViewState();
}

class _CariAccountsViewState extends State<CariAccountsView> {
  @override
  void initState() {
    super.initState();
    CariService.to.refresh();
  }

  Future<void> _addAccount() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Cari hesabı ekle', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: _textPrimary),
          cursorColor: _orange,
          decoration: InputDecoration(
            labelText: 'Müşteri / cari adı',
            labelStyle: TextStyle(color: _textSecondary),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _orange, width: 1.5),
            ),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç', style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    // Let the dialog's dismiss animation finish before disposing the field.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final created = await CariService.to.createAccount(name);
    if (created == null) {
      AppToast.error('Cari hesap eklenemedi');
    } else {
      AppToast.success('Cari hesap eklendi');
    }
  }

  double _openBalance(Map<String, dynamic> account) {
    final transactions =
        (account['transactions'] as List? ?? const []).cast<Map>();
    return transactions.where((t) => t['status'] != 'paid').fold<double>(
          0,
          (sum, t) => sum + ((t['total'] as num?)?.toDouble() ?? 0),
        );
  }

  int _openCount(Map<String, dynamic> account) {
    final transactions =
        (account['transactions'] as List? ?? const []).cast<Map>();
    return transactions.where((t) => t['status'] != 'paid').length;
  }

  void _showDetails(String accountId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Obx(() {
        final account = CariService.to.accounts.firstWhere(
          (a) => a['id'] == accountId,
          orElse: () => <String, dynamic>{'id': accountId, 'name': 'Cari'},
        );
        return _CariDetailsSheet(
          account: account,
          onComplete: _completeTransaction,
          onDelete: _deleteTransaction,
        );
      }),
    );
  }

  Future<void> _completeTransaction(Map<String, dynamic> transaction) async {
    final method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Ödemeyi tamamla', style: TextStyle(color: _textPrimary)),
        content: Text(
          'Ödeme yöntemi seçin',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          for (final type in SettingsService.to.paymentTypes)
            TextButton(
              onPressed: () => Navigator.pop(context, type.id),
              child: Text(type.name),
            ),
        ],
      ),
    );
    if (method == null) return;
    final ok = await CariService.to.markPaid(
      transaction,
      paymentMethod: method,
    );
    if (ok) {
      AppToast.success('Cari ödeme tamamlandı');
    } else {
      AppToast.error('Cari ödeme tamamlanamadı');
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final confirmed = await AppDialog.confirm(
      icon: CupertinoIcons.trash_fill,
      iconColor: _red,
      title: 'Cari kaydını sil',
      message: 'Bu cari hareket silinsin mi? Bu işlem geri alınamaz.',
      confirmText: 'Sil',
      cancelText: 'Vazgeç',
      destructive: true,
    );
    if (!confirmed) return;
    final id = transaction['id'] as String?;
    if (id == null) return;
    final ok = await CariService.to.deleteTransaction(id);
    if (ok) AppToast.success('Cari kaydı silindi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
                right: 8,
              ),
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
                      'Cari Hesaplar',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Cari hesabı ekle',
                      onPressed: _addAccount,
                      icon: Icon(CupertinoIcons.person_add,
                          color: _orange, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ResponsiveContent(
                width: ContentWidth.form,
                child: Obx(() {
                  final service = CariService.to;
                  if (service.isLoading.value && service.accounts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (service.accounts.isEmpty) {
                    return _EmptyCariState(onAdd: _addAccount);
                  }
                  return RefreshIndicator(
                    onRefresh: service.refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                      itemCount: service.accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final account = service.accounts[index];
                        final balance = _openBalance(account);
                        final count = _openCount(account);
                        return _AccountCard(
                          account: account,
                          balance: balance,
                          openCount: count,
                          onTap: () => _showDetails(account['id'] as String),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCariState extends StatelessWidget {
  const _EmptyCariState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                size: 52, color: _textSecondary),
            const SizedBox(height: 14),
            Text(
              'Henüz cari hesap yok',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Masa hesabı gönderebilmek için önce bir cari hesap ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(CupertinoIcons.plus),
              label: const Text('Cari hesabı ekle'),
              style: FilledButton.styleFrom(backgroundColor: _orange),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.balance,
    required this.openCount,
    required this.onTap,
  });

  final Map<String, dynamic> account;
  final double balance;
  final int openCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.person_fill,
                    color: _orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['name'] as String? ?? 'Cari',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      openCount == 0
                          ? 'Açık hesap yok'
                          : '$openCount açık masa hesabı',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Obx(() => Text(
                    '${SettingsService.cs}${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: balance > 0 ? _orange : _green,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  )),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_right,
                  size: 16, color: _textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CariDetailsSheet extends StatelessWidget {
  const _CariDetailsSheet({
    required this.account,
    required this.onComplete,
    required this.onDelete,
  });

  final Map<String, dynamic> account;
  final Future<void> Function(Map<String, dynamic>) onComplete;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final transactions = (account['transactions'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      account['name'] as String? ?? 'Cari Hesap',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Obx(() {
                    final balance = transactions
                        .where((t) => t['status'] != 'paid')
                        .fold<double>(
                          0,
                          (sum, t) =>
                              sum + ((t['total'] as num?)?.toDouble() ?? 0),
                        );
                    return Text(
                      '${SettingsService.cs}${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _orange,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Divider(height: 1, color: _border),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text('Bu cari hesapta hareket yok',
                          style: TextStyle(color: _textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _TransactionCard(
                        transaction: transactions[index],
                        onComplete: () => onComplete(transactions[index]),
                        onDelete: () => onDelete(transactions[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onComplete,
    required this.onDelete,
  });

  final Map<String, dynamic> transaction;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  String _dateLabel() {
    final raw = transaction['created_at'] as String?;
    if (raw == null) return '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  double _itemTotal(Map<String, dynamic> item) =>
      ((item['quantity'] as num?)?.toDouble() ?? 0) *
      ((item['price'] as num?)?.toDouble() ?? 0);

  @override
  Widget build(BuildContext context) {
    final isPaid = transaction['status'] == 'paid';
    final items = (transaction['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final total = (transaction['total'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaid
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.clock_fill,
                color: isPaid ? _green : _orange,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  transaction['table_name'] as String? ?? 'Masa',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${SettingsService.cs}${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isPaid ? _green : _orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _dateLabel(),
            style: TextStyle(color: _textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item['quantity']} × ${item['name']} · '
                '${SettingsService.cs}'
                '${_itemTotal(item).toStringAsFixed(2)}',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
          ),
          if (isPaid) ...[
            const SizedBox(height: 8),
            Text(
              'Tamamlandı · ${SettingsService.to.paymentMethodLabel(
                transaction['payment_method'] as String? ?? 'cash',
              )}',
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isPaid)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(CupertinoIcons.checkmark, size: 16),
                    label: const Text('Tamamlandı'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: BorderSide(color: _green.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              if (!isPaid) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(CupertinoIcons.trash, size: 16),
                  label: const Text('Sil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(color: _red.withValues(alpha: 0.5)),
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
