import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/widgets/app_toast.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg            = Color(0xFFF2F2F7);
const _card          = Colors.white;
const _orange        = Color(0xFFFF9500);
const _textPrimary   = Color(0xFF1C1C1E);
const _textSecondary = Color(0xFF8E8E93);
const _border        = Color(0xFFE5E5EA);

// ── Menu icon key → IconData ──────────────────────────────────
IconData _menuIconData(String key) {
  const map = <String, IconData>{
    'restaurant_menu': Icons.restaurant_menu_rounded,
    'local_cafe':      Icons.local_cafe_rounded,
    'coffee':          Icons.coffee_rounded,
    'free_breakfast':  Icons.free_breakfast_rounded,
    'food_beverage':   Icons.emoji_food_beverage_rounded,
    'water_drop':      Icons.water_drop_rounded,
    'local_bar':       Icons.local_bar_rounded,
    'wine_bar':        Icons.wine_bar_rounded,
    'sports_bar':      Icons.sports_bar_rounded,
    'liquor':          Icons.liquor_rounded,
    'local_pizza':     Icons.local_pizza_rounded,
    'fastfood':        Icons.fastfood_rounded,
    'lunch_dining':    Icons.lunch_dining_rounded,
    'dinner_dining':   Icons.dinner_dining_rounded,
    'breakfast_dining':Icons.breakfast_dining_rounded,
    'ramen_dining':    Icons.ramen_dining_rounded,
    'kebab_dining':    Icons.kebab_dining_rounded,
    'rice_bowl':       Icons.rice_bowl_rounded,
    'set_meal':        Icons.set_meal_rounded,
    'bakery_dining':   Icons.bakery_dining_rounded,
    'cake':            Icons.cake_rounded,
    'icecream':        Icons.icecream_rounded,
    'egg':             Icons.egg_rounded,
    'eco':             Icons.eco_rounded,
  };
  return map[key] ?? Icons.restaurant_menu_rounded;
}

class TableDetailView extends StatefulWidget {
  final int tableNumber;
  final String tableName;
  final bool isOccupied;
  final int tableIndex;

  const TableDetailView({
    super.key,
    required this.tableNumber,
    required this.tableName,
    required this.isOccupied,
    required this.tableIndex,
  });

  @override
  State<TableDetailView> createState() => _TableDetailViewState();
}

class _TableDetailViewState extends State<TableDetailView> {
  int _selectedMenuIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isPartialPayMode = false;
  // itemName → how many units the cashier has tapped to pay this round
  final Map<String, int> _partialSelected = {};
  final TextEditingController _searchController = TextEditingController();

  /// Always reads from the reactive service — updates on any device in real-time.
  List<Map<String, dynamic>> get _partialPayments =>
      TableService.to.getPartialPayments(widget.tableIndex);

  /// Returns "Section · TableName" when a section exists, otherwise just TableName.
  /// Used in every place where the user needs to identify which table they're on.
  String get _fullTableLabel {
    final tables = TableService.to.tables;
    if (widget.tableIndex >= tables.length) return widget.tableName;
    final sectionId = tables[widget.tableIndex]['sectionId'] as String?;
    final sectionName = SectionService.to.nameById(sectionId);
    if (sectionName != null && sectionName.isNotEmpty) {
      return '$sectionName · ${widget.tableName}';
    }
    return widget.tableName;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _safeMenuIndex {
    final count = MenuService.to.menus.length;
    if (count == 0) return 0;
    return _selectedMenuIndex.clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            return Column(
              children: [
                // Top bar
                _buildTopBar(context),
                // Main content
                Expanded(
                  child: isMobile
                      ? _buildMobileLayout(context)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCategorySidebar(),
                            Expanded(flex: 3, child: _buildMenuSection()),
                            _buildOrderPanel(context, width: 440),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
    );
  }

  // ── Mobile layout: horizontal category tabs + full-width order + checkout ──
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildMobileHorizontalCategories(context),
        const Divider(color: _border, height: 1),
        Expanded(child: _buildMobileOrderTop(context)),
        _buildMobileCheckoutBottom(context),
      ],
    );
  }

  Widget _buildMobileHorizontalCategories(BuildContext context) {
    return Container(
      height: 52,
      color: _card,
      child: Obx(() {
        // Observe icon changes so the bar rebuilds when icons update.
        final _ = MenuService.to.menuIcons.length;
        final menus = MenuService.to.menus;
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: menus.length,
          itemBuilder: (_, index) {
            final menu = menus[index];
            final iconKey = MenuService.to.getMenuIcon(menu['id'] as int);
            final isActive = index == _safeMenuIndex;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedMenuIndex = index);
                _showMenuBottomSheet(context, index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isActive ? _orange : _bg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [BoxShadow(color: _orange.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _menuIconData(iconKey),
                      size: 14,
                      color: isActive ? Colors.white : _textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      menu['name'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? Colors.white : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(String itemName, int index) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 26, color: Color(0xFFFF3B30)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Siparişi Kaldır',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"$itemName" siparişten kaldırılsın mı?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'İptal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                        TableService.to.removeOrder(widget.tableIndex, index);
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Kaldır',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMobileOrderTop(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          // ── Header card ──
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sipariş Detayı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _fullTableLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Order items ──
          Expanded(
            child: Obx(() {
              final orders = TableService.to.getOrders(widget.tableIndex);
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 44, color: _textSecondary),
                      const SizedBox(height: 12),
                      Text('no_orders_yet'.tr,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final name     = order['name']     as String;
                  final quantity = order['quantity'] as int;
                  final price    = order['price']    as double;
                  final lineTotal = price * quantity;
                  final isPartial = _isPartialPayMode;
                  final selCount = isPartial ? (_partialSelected[name] ?? 0) : 0;
                  return GestureDetector(
                    key: ValueKey(order['id']),
                    onTap: isPartial
                        ? () {
                            setState(() {
                              final cur = _partialSelected[name] ?? 0;
                              _partialSelected[name] = (cur + 1) % (quantity + 1);
                            });
                          }
                        : null,
                    child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPartial && selCount > 0
                          ? _orange.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isPartial
                          ? Border.all(
                              color: selCount > 0
                                  ? _orange.withOpacity(0.7)
                                  : _orange.withOpacity(0.2),
                              width: selCount > 0 ? 2.0 : 1.0)
                          : null,
                      boxShadow: const [
                        BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Qty display ──
                        isPartial
                            ? Container(
                                width: 32,
                                alignment: Alignment.center,
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _orange,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => TableService.to
                                          .decrementOrder(widget.tableIndex, index),
                                      child: const SizedBox(
                                        width: 38,
                                        height: 42,
                                        child: Icon(Icons.remove_rounded,
                                            size: 16, color: _textSecondary),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '$quantity',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => TableService.to
                                          .addOrder(widget.tableIndex, name, price),
                                      child: const SizedBox(
                                        width: 38,
                                        height: 42,
                                        child: Icon(Icons.add_rounded,
                                            size: 16, color: _textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(width: 12),
                        // ── Name ──
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Price ──
                        Text(
                          '${SettingsService.cs}${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _orange,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Delete / counter badge ──
                        isPartial
                            ? Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: selCount > 0 ? _orange : _bg,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$selCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: selCount > 0 ? Colors.white : _textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _confirmDelete(name, index),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Color(0xFFFF3B30)),
                                ),
                              ),
                      ],
                    ),
                  ));
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCheckoutBottom(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0E000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Totals ──
          Obx(() {
            final subtotal   = TableService.to.getTotal(widget.tableIndex);
            final discount   = TableService.to.getDiscount(widget.tableIndex);
            final finalTotal = TableService.to.getTotalWithDiscount(widget.tableIndex);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Ara Toplam',
                    value: '${SettingsService.cs}${subtotal.toStringAsFixed(2)}',
                  ),
                  if (discount > 0)
                    _SummaryRow(
                      label: 'İndirim',
                      value: '-${SettingsService.cs}${discount.toStringAsFixed(2)}',
                      valueColor: _orange,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        '${SettingsService.cs}${finalTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: _orange,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          // ── Action buttons — evenly spread ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionBtn(icon: Icons.add_circle_outline, label: 'new'.tr,      color: AppTheme.accentColor,    onTap: _handleNewOrder),
                _ActionBtn(icon: Icons.discount,           label: 'discount'.tr, color: AppTheme.warningColor,   onTap: _handleDiscount),
                _ActionBtn(icon: Icons.print,              label: 'print'.tr,    color: const Color(0xFF616161), onTap: _handlePrint),
                _ActionBtn(icon: Icons.compare_arrows,     label: 'move'.tr,     color: AppTheme.accentColor,    onTap: _handleMove),
              ],
            ),
          ),
          // ── Payment buttons ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomPad),
            child: _isPartialPayMode
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mode banner
                      Builder(builder: (_) {
                        final hasSelected = _partialSelected.values.any((v) => v > 0);
                        final selTotal = _selectedTotal;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _orange.withOpacity(0.18)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasSelected ? Icons.check_circle_outline_rounded : Icons.touch_app_rounded,
                                size: 16, color: _orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasSelected
                                    ? '${_partialSelected.values.fold(0, (s, v) => s + v)} ürün seçildi · ${SettingsService.cs}${selTotal.toStringAsFixed(2)}'
                                    : 'Ödemek istediğiniz ürüne dokunun',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: hasSelected ? _orange : _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textSecondary,
                                  side: const BorderSide(
                                      color: Color(0xFFE5E5EA), width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => setState(() {
                                  _isPartialPayMode = false;
                                  _partialSelected.clear();
                                }),
                                child: const Text(
                                  'İptal Et',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: _partialSelected.values.any((v) => v > 0)
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _orange,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                      ),
                                      onPressed: _confirmPartialPayments,
                                      child: Text(
                                        'Öde · ${SettingsService.cs}${_selectedTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3A3A3C),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                      ),
                                      onPressed: _showPartialPaymentsPanel,
                                      child: Obx(() {
                                        final payments = TableService.to.getPartialPayments(widget.tableIndex);
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Ödemeler',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14),
                                            ),
                                            if (payments.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${payments.length}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      }),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A3A3C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () {
                              final orders = TableService.to
                                  .getOrders(widget.tableIndex);
                              if (orders.isEmpty) {
                                AppToast.warning('empty_no_pay'.tr, title: 'warning'.tr);
                                return;
                              }
                              setState(() => _isPartialPayMode = true);
                            },
                            child: const Text(
                              'Parçalı Ödeme Al',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _handlePayment,
                            child: const Text(
                              'Toplu Ödeme Al',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCategorySidebar(BuildContext context) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(2, 0)),
        ],
      ),
      child: Obx(
        () {
          // Touch menuIcons so this Obx rebuilds when icons change.
          final _ = MenuService.to.menuIcons.length;
          return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: MenuService.to.menus.length,
          itemBuilder: (context, index) {
            final menu = MenuService.to.menus[index];
            final iconKey = MenuService.to.getMenuIcon(menu['id'] as int);
            return GestureDetector(
              onTap: () {
                setState(() => _selectedMenuIndex = index);
                _showMenuBottomSheet(context, index);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: index == _safeMenuIndex
                      ? _orange.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: index == _safeMenuIndex
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFBF4D), _orange],
                              )
                            : null,
                        color: index == _safeMenuIndex ? null : _bg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: index == _safeMenuIndex
                            ? [BoxShadow(color: _orange.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Icon(
                        _menuIconData(iconKey),
                        size: 20,
                        color: index == _safeMenuIndex ? Colors.white : _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      menu['name'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        color: index == _safeMenuIndex ? _orange : _textSecondary,
                        fontWeight: index == _safeMenuIndex ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
        },
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, int categoryIndex) {
    final menus = MenuService.to.menus;
    if (menus.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int selectedCategory = categoryIndex;
        String localSearch = '';
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final items = localSearch.isEmpty
                ? List<Map<String, dynamic>>.from(
                    (menus[selectedCategory]['items'] as List)
                        .map((i) => i as Map<String, dynamic>))
                : () {
                    final results = <Map<String, dynamic>>[];
                    for (final menu in menus) {
                      for (final item in (menu['items'] as List)) {
                        final m = item as Map<String, dynamic>;
                        if ((m['name'] as String).toLowerCase().contains(localSearch)) {
                          results.add(m);
                        }
                      }
                    }
                    return results;
                  }();

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.45,
              maxChildSize: 0.97,
              builder: (ctx, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                      child: Row(
                        children: [
                          Icon(
                            _menuIconData(MenuService.to.getMenuIcon(
                                menus[selectedCategory]['id'] as int)),
                            color: _orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            menus[selectedCategory]['name'] as String,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _textSecondary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 18, color: _textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Horizontal category tabs ──
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: menus.length,
                        itemBuilder: (_, i) {
                          final isActive = i == selectedCategory;
                          return GestureDetector(
                            onTap: () {
                              if (i == selectedCategory) return;
                              searchCtrl.clear();
                              setSheetState(() {
                                selectedCategory = i;
                                localSearch = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isActive ? _orange : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isActive
                                    ? [BoxShadow(color: _orange.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 2))]
                                    : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                menus[i]['name'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                  color: isActive ? Colors.white : _textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'search_menu'.tr,
                          hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: _orange, width: 1.5),
                          ),
                        ),
                        onChanged: (v) => setSheetState(() => localSearch = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Items grid
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                localSearch.isNotEmpty ? 'Sonuç bulunamadı' : 'no_menu_defined'.tr,
                                style: const TextStyle(color: _textSecondary, fontSize: 15),
                              ),
                            )
                          : GridView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                final item = items[i];
                                final name = item['name'] as String;
                                final price = item['price'] as double;
                                final imageUrl = item['imageUrl'] as String?;
                                return Obx(() {
                                  final isOut = InventoryService.to.isOutOfStock(name);
                                  final isLow = InventoryService.to.isLowStock(name);
                                  final isTracked = InventoryService.to.isTracked(name);
                                  final stockVal = InventoryService.to.getStock(name);
                                  return InkWell(
                                    onTap: () {
                                      if (isOut) {
                                        AppToast.warning('$name stokta yok!', title: 'warning'.tr);
                                        return;
                                      }
                                      TableService.to.addOrder(
                                        widget.tableIndex,
                                        name,
                                        price,
                                      );
                                      AppToast.success('$name eklendi', duration: const Duration(milliseconds: 800));
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        _buildMenuCard(
                                          name,
                                          '${SettingsService.cs}${price.toStringAsFixed(2)}',
                                          imageUrl: imageUrl,
                                          dimmed: isOut,
                                        ),
                                        if (isTracked)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isOut
                                                    ? const Color(0xFFFF3B30)
                                                    : isLow
                                                        ? _orange
                                                        : const Color(0xFF34C759),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isOut ? 'Bitti' : '$stockVal',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                });
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      // Absorb status bar so white extends seamlessly behind system UI
      padding: EdgeInsets.only(top: topPad),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _textPrimary),
              onPressed: () => Get.back(),
            ),
            // Centered title
            Expanded(
              child: Text(
                _fullTableLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _textPrimary,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Order count badge
            Obx(() {
              final orders = TableService.to.getOrders(widget.tableIndex);
              final count = orders.fold<int>(
                  0, (sum, o) => sum + (o['quantity'] as int));
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: _textSecondary, size: 22),
                    if (count > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: _orange,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySidebar() {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Obx(
              () {
                // Touch menuIcons so this Obx rebuilds when icons change.
                final _ = MenuService.to.menuIcons.length;
                return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: MenuService.to.menus.length,
                itemBuilder: (context, index) {
                  final menu = MenuService.to.menus[index];
                  final isSelected = index == _safeMenuIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMenuIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _orange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? const Border(
                                left: BorderSide(color: _orange, width: 3),
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFFBF4D), _orange],
                                    )
                                  : null,
                              color: isSelected ? null : _bg,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: _orange.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: Icon(
                              _menuIconData(MenuService.to.getMenuIcon(menu['id'] as int)),
                              size: 20,
                              color: isSelected ? Colors.white : _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            menu['name'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? _orange : _textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      color: _bg,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_menu'.tr,
                hintStyle: const TextStyle(
                    color: _textSecondary, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: _textSecondary, size: 20),
                suffixIcon: const Icon(Icons.tune,
                    color: _textSecondary, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: _orange, width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                  _isSearching = value.isNotEmpty;
                });
              },
            ),
          ),
          Expanded(child: _buildMenuGrid()),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Obx(() {
      // Touch stock so this Obx rebuilds when inventory changes.
      // ignore: unused_local_variable
      final _stockLen = InventoryService.to.stock.length;
      final menus = MenuService.to.menus;

      if (menus.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu,
                  size: 48, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                'no_menu_defined'.tr,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      List<Map<String, dynamic>> items;
      if (_isSearching && _searchQuery.isNotEmpty) {
        items = [];
        for (final menu in menus) {
          for (final item in (menu['items'] as List)) {
            final itemMap = item as Map<String, dynamic>;
            if ((itemMap['name'] as String)
                .toLowerCase()
                .contains(_searchQuery)) {
              items.add(itemMap);
            }
          }
        }
      } else {
        final safeIdx = _safeMenuIndex;
        items = List<Map<String, dynamic>>.from(
          (menus[safeIdx]['items'] as List)
              .map((i) => i as Map<String, dynamic>),
        );
      }

      if (items.isEmpty) {
        return Center(
          child: Text(
            _isSearching ? 'Sonuç bulunamadı' : 'no_menu_defined'.tr,
            style: const TextStyle(color: _textSecondary, fontSize: 16),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth < 300
              ? 2
              : constraints.maxWidth < 420
                  ? 3
                  : 4;
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final name = item['name'] as String;
              final isOut = InventoryService.to.isOutOfStock(name);
              final isLow = InventoryService.to.isLowStock(name);
              final isTracked = InventoryService.to.isTracked(name);
              final stockVal = InventoryService.to.getStock(name);

              return InkWell(
                onTap: () {
                  if (isOut) {
                    AppToast.warning('$name stokta yok!', title: 'warning'.tr);
                    return;
                  }
                  TableService.to.addOrder(
                    widget.tableIndex,
                    name,
                    item['price'] as double,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    _buildMenuCard(
                      name,
                      '${SettingsService.cs}${(item['price'] as double).toStringAsFixed(2)}',
                      imageUrl: item['imageUrl'] as String?,
                      dimmed: isOut,
                    ),
                    if (isTracked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOut
                                ? const Color(0xFFFF3B30)
                                : isLow
                                    ? _orange
                                    : const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut ? 'Bitti' : '$stockVal',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _buildMenuCard(String name, String price, {String? imageUrl, bool dimmed = false}) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: dimmed
              ? []
              : [
                  BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 2)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — ~60% of card height, proportional
            Expanded(
              flex: 10,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _cardGradient(),
                        errorBuilder: (_, __, ___) => _cardGradient(),
                      )
                    : _cardGradient(),
              ),
            ),
            // Info — ~40% of card height
            Expanded(
              flex: 7,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compact layout for narrow cards (phone 3-col ~111px wide)
                  final isCompact = constraints.maxWidth < 140;
                  final btnSize  = isCompact ? 24.0 : 30.0;
                  final btnRadius = isCompact ? 8.0  : 10.0;
                  final iconSize = isCompact ? 14.0  : 18.0;
                  final priceSize = isCompact ? 13.0 : 15.0;
                  final hPad    = isCompact ? 8.0   : 12.0;
                  return Padding(
                padding: EdgeInsets.fromLTRB(hPad, isCompact ? 6 : 8, isCompact ? 7 : 10, isCompact ? 8 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isCompact ? 12.0 : 13.0,
                        color: const Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                          price,
                          style: TextStyle(
                            fontSize: priceSize,
                            color: _orange,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: btnSize,
                          height: btnSize,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFBF4D), _orange],
                            ),
                            borderRadius: BorderRadius.circular(btnRadius),
                            boxShadow: [
                              BoxShadow(color: _orange.withOpacity(0.40), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Icon(Icons.add_rounded, color: Colors.white, size: iconSize),
                        ),
                      ],
                    ),
                  ],
                ),
              );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFBF4D), _orange],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(Icons.fastfood_rounded, size: 32, color: Colors.white.withOpacity(0.9)),
      ),
    );
  }

  Widget _buildOrderPanel(BuildContext context, {double? width}) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(-2, 0)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sipariş Detayı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _textPrimary,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _fullTableLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _border, height: 1),
          // Order list
          Expanded(
            child: Obx(() {
              final orders = TableService.to.getOrders(widget.tableIndex);
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 48, color: _textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'no_orders_yet'.tr,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: _border, height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final name = order['name'] as String;
                  final quantity = order['quantity'] as int;
                  final price = order['price'] as double;
                  final lineTotal = price * quantity;
                  final isPartial = _isPartialPayMode;
                  final selCount = isPartial ? (_partialSelected[name] ?? 0) : 0;
                  return GestureDetector(
                    key: ValueKey(order['id']),
                    onTap: isPartial
                        ? () {
                            setState(() {
                              final cur = _partialSelected[name] ?? 0;
                              _partialSelected[name] = (cur + 1) % (quantity + 1);
                            });
                          }
                        : null,
                    child: Container(
                      color: isPartial && selCount > 0
                          ? _orange.withOpacity(0.05)
                          : Colors.transparent,
                      child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Qty display
                        isPartial
                            ? Container(
                                width: 32,
                                alignment: Alignment.center,
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _orange,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => TableService.to
                                          .decrementOrder(widget.tableIndex, index),
                                      child: const SizedBox(
                                        width: 38,
                                        height: 42,
                                        child: Icon(Icons.remove_rounded,
                                            size: 16, color: _textSecondary),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '$quantity',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => TableService.to
                                          .addOrder(widget.tableIndex, name, price),
                                      child: const SizedBox(
                                        width: 38,
                                        height: 42,
                                        child: Icon(Icons.add_rounded,
                                            size: 16, color: _textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(width: 10),
                        // Item name
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Price
                        Text(
                          '${SettingsService.cs}${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _orange,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete / counter badge
                        isPartial
                            ? Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: selCount > 0 ? _orange : _bg,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$selCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: selCount > 0 ? Colors.white : _textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _confirmDelete(name, index),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30)
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: Color(0xFFFF3B30)),
                                ),
                              ),
                      ],
                    ),
                  ),
                    ),
                  );
                },
              );
            }),
          ),
          const Divider(color: _border, height: 1),
          // Payment summary
          Obx(() {
            final subtotal = TableService.to.getTotal(widget.tableIndex);
            final discount = TableService.to.getDiscount(widget.tableIndex);
            final finalTotal =
                TableService.to.getTotalWithDiscount(widget.tableIndex);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Ara Toplam',
                    value: '${SettingsService.cs}${subtotal.toStringAsFixed(2)}',
                  ),
                  if (discount > 0)
                    _SummaryRow(
                      label: 'İndirim',
                      value: '-${SettingsService.cs}${discount.toStringAsFixed(2)}',
                      valueColor: _orange,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _textPrimary,
                            ),
                      ),
                      Text(
                        '${SettingsService.cs}${finalTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          // Action buttons row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.add_circle_outline,
                    label: 'new'.tr,
                    color: AppTheme.accentColor,
                    onTap: _handleNewOrder,
                  ),
                  _ActionBtn(
                    icon: Icons.discount,
                    label: 'discount'.tr,
                    color: AppTheme.warningColor,
                    onTap: _handleDiscount,
                  ),
                  _ActionBtn(
                    icon: Icons.print,
                    label: 'print'.tr,
                    color: const Color(0xFF616161),
                    onTap: _handlePrint,
                  ),
                  _ActionBtn(
                    icon: Icons.compare_arrows,
                    label: 'move'.tr,
                    color: AppTheme.accentColor,
                    onTap: _handleMove,
                  ),
                ],
              ),
            ),
          ),
          // Checkout buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isPartialPayMode
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(builder: (_) {
                        final hasSelected = _partialSelected.values.any((v) => v > 0);
                        final selTotal = _selectedTotal;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _orange.withOpacity(0.18)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasSelected ? Icons.check_circle_outline_rounded : Icons.touch_app_rounded,
                                size: 15, color: _orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasSelected
                                    ? '${_partialSelected.values.fold(0, (s, v) => s + v)} ürün seçildi · ${SettingsService.cs}${selTotal.toStringAsFixed(2)}'
                                    : 'Ödemek istediğiniz ürüne dokunun',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: hasSelected ? _orange : _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textSecondary,
                                  side: const BorderSide(
                                      color: Color(0xFFE5E5EA),
                                      width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                onPressed: () => setState(() {
                                  _isPartialPayMode = false;
                                  _partialSelected.clear();
                                }),
                                child: const Text(
                                  'İptal Et',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: _partialSelected.values.any((v) => v > 0)
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _orange,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: _confirmPartialPayments,
                                      child: Text(
                                        'Öde · ${SettingsService.cs}${_selectedTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3A3A3C),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: _showPartialPaymentsPanel,
                                      child: Obx(() {
                                        final payments = TableService.to.getPartialPayments(widget.tableIndex);
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Ödemeler',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                            ),
                                            if (payments.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${payments.length}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      }),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF3A3A3C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              final orders = TableService.to
                                  .getOrders(widget.tableIndex);
                              if (orders.isEmpty) {
                                AppToast.warning('empty_no_pay'.tr, title: 'warning'.tr);
                                return;
                              }
                              setState(
                                  () => _isPartialPayMode = true);
                            },
                            child: const Text(
                              'Parçalı Ödeme Al',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _handlePayment,
                            child: const Text(
                              'Toplu Ödeme Al',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Clear table (new order)
  void _handleNewOrder() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      AppToast.info('table_already_empty'.tr, title: 'info'.tr);
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('clear_table'.tr),
        content: Text('clear_table_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              TableService.to.clearTable(widget.tableIndex);
              Get.back();
              AppToast.success('table_cleared'.tr, title: 'success'.tr);
            },
            child: Text('clear'.tr),
          ),
        ],
      ),
    );
  }

  // Apply discount
  void _handleDiscount() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      AppToast.warning('empty_no_discount'.tr, title: 'warning'.tr);
      return;
    }

    final TextEditingController discountController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('apply_discount'.tr),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${'total'.tr}: ${SettingsService.cs}${TableService.to.getTotal(widget.tableIndex).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'discount_percent'.tr,
                  border: const OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final discount = double.tryParse(discountController.text);
              if (discount != null && discount > 0 && discount <= 100) {
                TableService.to
                    .applyDiscount(widget.tableIndex, discount);
                Get.back();
                AppToast.success('discount_applied'.tr, title: 'success'.tr);
              } else {
                AppToast.error('valid_discount'.tr, title: 'error'.tr);
              }
            },
            child: Text('apply'.tr),
          ),
        ],
      ),
    );
  }

  // Print receipt — generates a real PDF
  Future<void> _handlePrint() async {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      AppToast.warning('empty_no_print'.tr, title: 'warning'.tr);
      return;
    }

    final subtotal = TableService.to.getTotal(widget.tableIndex);
    final discount = TableService.to.getDiscount(widget.tableIndex);
    final finalTotal =
        TableService.to.getTotalWithDiscount(widget.tableIndex);

    try {
      final companyName = SettingsService.to.companyName.value.isNotEmpty
          ? SettingsService.to.companyName.value
          : 'Orderix';

      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    companyName,
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    _fullTableLabel,
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(font: regularFont, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 4),
                ...orders.map(
                  (order) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${order['quantity']}x  ${order['name']}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 12),
                        ),
                        pw.Text(
                          'TL ${((order['price'] as double) * (order['quantity'] as int)).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.SizedBox(height: 4),
                if (discount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Ara Toplam',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                      pw.Text('TL ${subtotal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Indirim',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                      pw.Text('-TL ${discount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              font: regularFont, fontSize: 11)),
                    ],
                  ),
                ],
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOPLAM',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14)),
                    pw.Text(
                        'TL ${finalTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    'Tesekkur ederiz!',
                    style:
                        pw.TextStyle(font: regularFont, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (format) async => doc.save());
    } catch (e) {
      AppToast.error('PDF olusturulurken hata: $e', title: 'error'.tr);
    }
  }

  // Move orders to another table
  void _handleMove() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      AppToast.warning('empty_no_move'.tr, title: 'warning'.tr);
      return;
    }

    showDialog(
      context: context,
      barrierColor: const Color(0x70000000),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 48,
                  offset: Offset(0, 16),
                ),
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _orange.withValues(alpha: 0.18),
                              _orange.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 22,
                          color: _orange,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'move_orders'.tr,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${orders.length} sipariş · ${_fullTableLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: _border),

                // ── Grouped table list ───────────────────────────
                Flexible(
                  child: Obx(() {
                    // Only empty tables are valid move targets
                    final emptyTables = TableService.to.tables
                        .asMap()
                        .entries
                        .where((e) =>
                            e.key != widget.tableIndex &&
                            !(e.value['isOccupied'] as bool))
                        .toList();

                    if (emptyTables.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.table_restaurant_rounded,
                                size: 28,
                                color: Color(0xFFC7C7CC),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Boş masa bulunamadı',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tüm masalar dolu.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Group by section — tables without a section go under null key
                    final Map<String?, List<MapEntry<int, Map<String, dynamic>>>> grouped = {};
                    for (final entry in emptyTables) {
                      final sectionId = entry.value['sectionId'] as String?;
                      final sectionName = SectionService.to.nameById(sectionId);
                      grouped.putIfAbsent(sectionName, () => []).add(entry);
                    }

                    // Sort: named sections alphabetically first, null last
                    final sectionKeys = grouped.keys.toList()
                      ..sort((a, b) {
                        if (a == null) return 1;
                        if (b == null) return -1;
                        return a.compareTo(b);
                      });

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        shrinkWrap: true,
                        itemCount: sectionKeys.length,
                        itemBuilder: (_, sectionIdx) {
                          final sectionName = sectionKeys[sectionIdx];
                          final sectionTables = grouped[sectionName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header
                              if (sectionName != null) ...[
                                if (sectionIdx > 0) const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, bottom: 8),
                                  child: Text(
                                    sectionName.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _textSecondary,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                              ] else if (sectionIdx > 0)
                                const SizedBox(height: 16),

                              // 2-column grid of table cards for this section
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 2.8,
                                ),
                                itemCount: sectionTables.length,
                                itemBuilder: (_, i) {
                                  final entry = sectionTables[i];
                                  final tableIdx = entry.key;
                                  final table = entry.value;
                                  final tableName = table['name'] as String;

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      splashColor:
                                          _orange.withValues(alpha: 0.08),
                                      highlightColor:
                                          _orange.withValues(alpha: 0.04),
                                      onTap: () {
                                        TableService.to.moveAllOrdersToTable(
                                            widget.tableIndex, tableIdx);
                                        Navigator.pop(ctx);
                                        Get.back();
                                        AppToast.success(
                                          '$tableName ${'moved_to_table'.tr}',
                                          title: 'success'.tr,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _card,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: _border, width: 1),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x08000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 13, vertical: 0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tableName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textPrimary,
                                                  letterSpacing: -0.2,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: _textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }),
                ),

                // ── Footer ──────────────────────────────────────
                const Divider(height: 1, color: _border),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'cancel'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Take payment
  // ── Partial payment ─────────────────────────────────────────

  void _showPartialPaymentsPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, minWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ödemeler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              // List — Obx so other-device payments appear in real-time
              Obx(() {
                final payments = TableService.to.getPartialPayments(widget.tableIndex);
                if (payments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Henüz ödeme yapılmamış',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: Color(0xFFE5E5EA), indent: 16, endIndent: 16),
                    itemBuilder: (ctx, i) {
                      final p = payments[i];
                      final methodIcon = p['method'] == 'cash'
                          ? Icons.payments_rounded
                          : p['method'] == 'card'
                              ? Icons.credit_card_rounded
                              : Icons.account_balance_rounded;
                      final methodLabel = p['method'] == 'cash'
                          ? 'Nakit'
                          : p['method'] == 'card'
                              ? 'Kart'
                              : 'Havale';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(methodIcon, size: 16, color: _orange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  Text(
                                    '${p['qty']}x · $methodLabel',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${SettingsService.cs}${(p['total'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
              // Footer total (also reactive)
              Obx(() {
                final payments = TableService.to.getPartialPayments(widget.tableIndex);
                if (payments.isEmpty) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1, color: Color(0xFFE5E5EA)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ödenen Toplam',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            '${SettingsService.cs}${payments.fold<double>(0, (s, p) => s + (p['total'] as double)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  double get _selectedTotal {
    final orders = TableService.to.getOrders(widget.tableIndex);
    double total = 0;
    for (final entry in _partialSelected.entries) {
      if (entry.value <= 0) continue;
      try {
        final order = orders.firstWhere((o) => o['name'] == entry.key);
        total += (order['price'] as double) * entry.value;
      } catch (_) {}
    }
    return total;
  }

  void _confirmPartialPayments() {
    final selected = Map<String, int>.from(_partialSelected)
      ..removeWhere((_, v) => v == 0);
    if (selected.isEmpty) return;

    final orders = TableService.to.getOrders(widget.tableIndex);

    // Pre-compute line totals for display
    final lineItems = <Map<String, dynamic>>[];
    double totalAmount = 0;
    for (final entry in selected.entries) {
      try {
        final order = orders.firstWhere((o) => o['name'] == entry.key);
        final price = order['price'] as double;
        final lineTotal = price * entry.value;
        totalAmount += lineTotal;
        lineItems.add({'name': entry.key, 'qty': entry.value, 'total': lineTotal});
      } catch (_) {}
    }
    if (lineItems.isEmpty) return;

    String selectedMethod = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seçilen Ürünler',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // Selected items list
              ...lineItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(
                        color: _orange, shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${item['qty']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${SettingsService.cs}${(item['total'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
              const Divider(height: 20, color: _border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Toplam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    '${SettingsService.cs}${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Ödeme Yöntemi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _PartialPayMethodBtn(
                    icon: Icons.payments_rounded,
                    label: 'pay_cash'.tr,
                    value: 'cash',
                    selected: selectedMethod == 'cash',
                    onTap: () => setSheet(() => selectedMethod = 'cash'),
                  ),
                  const SizedBox(width: 10),
                  _PartialPayMethodBtn(
                    icon: Icons.credit_card_rounded,
                    label: 'pay_card'.tr,
                    value: 'card',
                    selected: selectedMethod == 'card',
                    onTap: () => setSheet(() => selectedMethod = 'card'),
                  ),
                  const SizedBox(width: 10),
                  _PartialPayMethodBtn(
                    icon: Icons.account_balance_rounded,
                    label: 'pay_transfer'.tr,
                    value: 'transfer',
                    selected: selectedMethod == 'transfer',
                    onTap: () => setSheet(() => selectedMethod = 'transfer'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final method = selectedMethod;
                    final toProcess = List<Map<String, dynamic>>.from(lineItems);
                    Navigator.pop(ctx);

                    // All in-memory updates are synchronous inside
                    // recordPartialPaymentUnits — fire all in parallel.
                    for (final item in toProcess) {
                      final itemName  = item['name']  as String;
                      final units     = item['qty']   as int;
                      final lineTotal = item['total'] as double;

                      // Instant in-memory update; DB writes fire in background.
                      TableService.to.recordPartialPaymentUnits(
                        widget.tableIndex,
                        itemName,
                        units,
                        paymentMethod: method,
                      ).ignore();

                      final record = {
                        'name': itemName,
                        'qty': units,
                        'total': lineTotal,
                        'method': method,
                      };
                      // addPartialPaymentRecord persists to DB + reactive map.
                      TableService.to.addPartialPaymentRecord(
                          widget.tableIndex, record);
                    }

                    setState(() {
                      _partialSelected.clear();
                      if (TableService.to
                          .getOrders(widget.tableIndex)
                          .isEmpty) {
                        _isPartialPayMode = false;
                      }
                    });

                    AppToast.info(
                      '${toProcess.length} kalem · ${SettingsService.cs}${totalAmount.toStringAsFixed(2)}',
                      title: 'Parça Ödeme Alındı',
                      duration: const Duration(seconds: 2),
                    );
                  },
                  child: Text(
                    'Öde · ${SettingsService.cs}${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePayment() {
    final orders = TableService.to.getOrders(widget.tableIndex);
    if (orders.isEmpty) {
      AppToast.warning('empty_no_pay'.tr, title: 'warning'.tr);
      return;
    }

    final total    = TableService.to.getTotal(widget.tableIndex);
    final discount = TableService.to.getDiscount(widget.tableIndex);
    final finalTotal = TableService.to.getTotalWithDiscount(widget.tableIndex);
    String selectedMethod = 'cash';
    bool splitEnabled = false;
    int splitCount = 2;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24, 0, 24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── drag handle ─────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── header ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppTheme.successColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'pay_title'.tr,
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          _fullTableLabel,
                          style: const TextStyle(
                            fontSize: 13, color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── total summary card ───────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (discount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('subtotal'.tr,
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 13)),
                            Text('${SettingsService.cs}${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('discount'.tr,
                                style: const TextStyle(
                                    color: AppTheme.warningColor,
                                    fontSize: 13)),
                            Text('-${SettingsService.cs}${discount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppTheme.warningColor,
                                    fontSize: 13)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1,
                              color: Colors.grey.shade300),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'total'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            '${SettingsService.cs}${finalTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Böl toggle row ───────────────────────────────
                GestureDetector(
                  onTap: () =>
                      setState(() => splitEnabled = !splitEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: splitEnabled
                          ? AppTheme.infoColor.withValues(alpha: 0.08)
                          : _bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: splitEnabled
                            ? AppTheme.infoColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.call_split_rounded,
                          color: splitEnabled
                              ? AppTheme.infoColor
                              : _textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'split'.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: splitEnabled
                                ? AppTheme.infoColor
                                : _textPrimary,
                          ),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: splitEnabled
                              ? const Icon(Icons.keyboard_arrow_up_rounded,
                                  color: AppTheme.infoColor,
                                  key: ValueKey('up'))
                              : const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _textSecondary,
                                  key: ValueKey('down')),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Split expanded panel ─────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  child: splitEnabled
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              // stepper
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  _StepperBtn(
                                    icon: Icons.remove_rounded,
                                    onTap: splitCount > 2
                                        ? () => setState(
                                            () => splitCount--)
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$splitCount',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'how_many_people'.tr,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StepperBtn(
                                    icon: Icons.add_rounded,
                                    onTap: () =>
                                        setState(() => splitCount++),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // per-person result
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.infoColor
                                          .withValues(alpha: 0.12),
                                      AppTheme.infoColor
                                          .withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'per_person'.tr,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${SettingsService.cs}${(finalTotal / splitCount).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.infoColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // ── Payment method label ─────────────────────────
                Text(
                  'pay_method'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Payment method 3-card row ────────────────────
                Row(
                  children: [
                    _PayCard(
                      label: 'pay_cash'.tr,
                      icon: Icons.payments_rounded,
                      selected: selectedMethod == 'cash',
                      onTap: () =>
                          setState(() => selectedMethod = 'cash'),
                    ),
                    const SizedBox(width: 8),
                    _PayCard(
                      label: 'pay_card'.tr,
                      icon: Icons.credit_card_rounded,
                      selected: selectedMethod == 'card',
                      onTap: () =>
                          setState(() => selectedMethod = 'card'),
                    ),
                    const SizedBox(width: 8),
                    _PayCard(
                      label: 'pay_transfer'.tr,
                      icon: Icons.account_balance_rounded,
                      selected: selectedMethod == 'transfer',
                      onTap: () =>
                          setState(() => selectedMethod = 'transfer'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Action buttons ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          side:
                              BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Get.back(),
                        child: Text(
                          'cancel'.tr,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          TableService.to.recordPayment(
                              widget.tableIndex,
                              paymentMethod: selectedMethod);
                          Get.back();
                          Get.back();
                          AppToast.success('payment_received'.tr,
                              title: 'success'.tr);
                        },
                        child: Text(
                          'pay'.tr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanded payment method button used in the partial pay bottom sheet.
class _PartialPayMethodBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PartialPayMethodBtn({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _orange : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22,
                  color: selected ? Colors.white : const Color(0xFF8E8E93)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: _textSecondary),
      ),
    );
  }
}

// ── Stepper button used in the split panel ────────────────────────────────────
class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: enabled ? _bg : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? _border : Colors.grey.shade200,
          ),
        ),
        child: Icon(icon,
            size: 20,
            color: enabled ? _textPrimary : _textSecondary),
      ),
    );
  }
}

// ── Payment method card used in the payment bottom sheet ─────────────────────
class _PayCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.successColor : _bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.successColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? Colors.white : _textSecondary),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? _textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
