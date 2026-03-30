import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'package:adisyos/widgets/app_toast.dart';

// ── Design tokens ──────────────────────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _orangeLight = Color(0xFFFFF4E0);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);

// ── Icon catalogue ─────────────────────────────────────────────

typedef _IconOpt = ({String key, IconData icon, String label});

const List<_IconOpt> _kMenuIcons = [
  (key: 'restaurant_menu', icon: Icons.restaurant_menu_rounded,    label: 'Menü'),
  (key: 'local_cafe',      icon: Icons.local_cafe_rounded,         label: 'Kafe'),
  (key: 'coffee',          icon: Icons.coffee_rounded,             label: 'Kahve'),
  (key: 'free_breakfast',  icon: Icons.free_breakfast_rounded,     label: 'Çay'),
  (key: 'food_beverage',   icon: Icons.emoji_food_beverage_rounded, label: 'İçecek'),
  (key: 'water_drop',      icon: Icons.water_drop_rounded,         label: 'Su'),
  (key: 'local_bar',       icon: Icons.local_bar_rounded,          label: 'Bar'),
  (key: 'wine_bar',        icon: Icons.wine_bar_rounded,           label: 'Şarap'),
  (key: 'sports_bar',      icon: Icons.sports_bar_rounded,         label: 'Bira'),
  (key: 'liquor',          icon: Icons.liquor_rounded,             label: 'Alkol'),
  (key: 'local_pizza',     icon: Icons.local_pizza_rounded,        label: 'Pizza'),
  (key: 'fastfood',        icon: Icons.fastfood_rounded,           label: 'Burger'),
  (key: 'lunch_dining',    icon: Icons.lunch_dining_rounded,       label: 'Öğle'),
  (key: 'dinner_dining',   icon: Icons.dinner_dining_rounded,      label: 'Akşam'),
  (key: 'breakfast_dining',icon: Icons.breakfast_dining_rounded,   label: 'Kahvaltı'),
  (key: 'ramen_dining',    icon: Icons.ramen_dining_rounded,       label: 'Noodle'),
  (key: 'kebab_dining',    icon: Icons.kebab_dining_rounded,       label: 'Kebap'),
  (key: 'rice_bowl',       icon: Icons.rice_bowl_rounded,          label: 'Pilav'),
  (key: 'set_meal',        icon: Icons.set_meal_rounded,           label: 'Set Menü'),
  (key: 'bakery_dining',   icon: Icons.bakery_dining_rounded,      label: 'Fırın'),
  (key: 'cake',            icon: Icons.cake_rounded,               label: 'Pasta'),
  (key: 'icecream',        icon: Icons.icecream_rounded,           label: 'Dondurma'),
  (key: 'egg',             icon: Icons.egg_rounded,                label: 'Yumurta'),
  (key: 'eco',             icon: Icons.eco_rounded,                label: 'Vegan'),
];

IconData _iconData(String key) => _kMenuIcons
    .firstWhere((o) => o.key == key, orElse: () => _kMenuIcons.first)
    .icon;

String _iconLabel(String key) => _kMenuIcons
    .firstWhere((o) => o.key == key, orElse: () => _kMenuIcons.first)
    .label;

// ──────────────────────────────────────────────────────────────
// MenuManagementView
// ──────────────────────────────────────────────────────────────

class MenuManagementView extends StatefulWidget {
  const MenuManagementView({super.key});

  @override
  State<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<MenuManagementView> {
  @override
  void initState() {
    super.initState();
    // Always fetch fresh data when this page is opened.
    MenuService.to.refresh();
  }

  // ── Dialog launchers ──────────────────────────────────────

  void _showAddMenuDialog() {
    showDialog(
      context: context,
      builder: (_) => const _MenuFormDialog(),
    );
  }

  void _showEditMenuDialog(int menuIndex, String currentName) {
    final menuId = MenuService.to.menus[menuIndex]['id'] as int;
    final iconKey = MenuService.to.getMenuIcon(menuId);
    showDialog(
      context: context,
      builder: (_) => _MenuFormDialog(
        menuIndex:      menuIndex,
        initialName:    currentName,
        initialIconKey: iconKey,
      ),
    );
  }

  void _showDeleteMenuConfirmation(int menuIndex, String menuName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('delete_menu'.tr),
        content: Text('"$menuName" ${'delete_menu_confirm'.tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              MenuService.to.removeMenu(menuIndex);
              Navigator.of(context).pop();
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(int menuIndex) {
    showDialog(
      context: context,
      builder: (_) => _ItemFormDialog(menuIndex: menuIndex),
    );
  }

  void _showEditItemDialog(
    int menuIndex,
    int itemIndex,
    String name,
    double price,
    String? imageUrl,
  ) {
    showDialog(
      context: context,
      builder: (_) => _ItemFormDialog(
        menuIndex:        menuIndex,
        itemIndex:        itemIndex,
        initialName:      name,
        initialPrice:     price,
        initialImageUrl:  imageUrl,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────
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
                    onPressed: Get.back,
                  ),
                  Text(
                    'menu_management'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: _showAddMenuDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44FF9500),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'add_menu'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────
            Expanded(
              child: Obx(
                () => MenuService.to.menus.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _textSec.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 48,
                                color: _textSec,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_menus'.tr,
                              style: const TextStyle(
                                color: _textSec,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _showAddMenuDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'add_menu'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: MenuService.to.menus.length,
                        itemBuilder: (_, menuIndex) {
                          final menu = MenuService.to.menus[menuIndex];
                          return _MenuCard(
                            menu: menu,
                            menuIndex: menuIndex,
                            onAddItem: () => _showAddItemDialog(menuIndex),
                            onEditMenu: () => _showEditMenuDialog(
                                menuIndex, menu['name'] as String),
                            onDeleteMenu: () => _showDeleteMenuConfirmation(
                                menuIndex, menu['name'] as String),
                            onEditItem: (itemIndex, name, price, imageUrl) =>
                                _showEditItemDialog(
                                    menuIndex, itemIndex, name, price, imageUrl),
                            onDeleteItem: (itemIndex) =>
                                MenuService.to.removeMenuItem(
                                    menuIndex, itemIndex),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _MenuFormDialog — add or edit a menu category + icon
// ──────────────────────────────────────────────────────────────

class _MenuFormDialog extends StatefulWidget {
  const _MenuFormDialog({
    this.menuIndex,
    this.initialName,
    this.initialIconKey,
  });

  final int?    menuIndex;      // null → add mode
  final String? initialName;
  final String? initialIconKey;

  @override
  State<_MenuFormDialog> createState() => _MenuFormDialogState();
}

class _MenuFormDialogState extends State<_MenuFormDialog> {
  late final TextEditingController _nameCtrl;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _iconKey  = widget.initialIconKey ?? 'restaurant_menu';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.menuIndex == null) {
      // Add
      MenuService.to.addMenu(name).then((id) {
        if (id != null) MenuService.to.setMenuIcon(id, _iconKey);
      });
    } else {
      // Edit
      final menuId = MenuService.to.menus[widget.menuIndex!]['id'] as int;
      MenuService.to.updateMenu(widget.menuIndex!, name);
      MenuService.to.setMenuIcon(menuId, _iconKey);
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.menuIndex == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                isAdd ? 'Menü Ekle' : 'Menü Düzenle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Name field
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'menu_name'.tr,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 22),

              // Icon picker
              const Text(
                'KATEGORİ İKONU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSec,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),

              // Current selection label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconData(_iconKey),
                        size: 16, color: _orange),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _iconLabel(_iconKey),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Grid
              _IconPickerGrid(
                selectedKey: _iconKey,
                onSelect: (k) => setState(() => _iconKey = k),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: Text('cancel'.tr),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _save,
                    child: Text('save'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _ItemFormDialog — add or edit a menu item + image
// ──────────────────────────────────────────────────────────────

class _ItemFormDialog extends StatefulWidget {
  const _ItemFormDialog({
    required this.menuIndex,
    this.itemIndex,
    this.initialName,
    this.initialPrice,
    this.initialImageUrl,
  });

  final int     menuIndex;
  final int?    itemIndex;      // null → add mode
  final String? initialName;
  final double? initialPrice;
  final String? initialImageUrl;

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  Uint8List? _pickedBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initialName ?? '');
    _priceCtrl = TextEditingController(
      text: widget.initialPrice != null
          ? widget.initialPrice!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source:       ImageSource.gallery,
        maxWidth:     900,
        maxHeight:    900,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() => _pickedBytes = bytes);
    } catch (e) {
      if (mounted) {
        AppToast.error('Fotoğraf seçilemedi: $e', title: 'Hata');
      }
    }
  }

  Future<void> _save() async {
    final name      = _nameCtrl.text.trim();
    final priceText = _priceCtrl.text.trim().replaceAll(',', '.');
    if (name.isEmpty || priceText.isEmpty) return;

    final price = double.tryParse(priceText);
    if (price == null || price < 0) {
      AppToast.error('invalid_price'.tr, title: 'error'.tr);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.itemIndex == null) {
        await MenuService.to.addMenuItem(
          widget.menuIndex,
          name,
          price,
          imageBytes: _pickedBytes,
        );
      } else {
        await MenuService.to.updateMenuItem(
          widget.menuIndex,
          widget.itemIndex!,
          name,
          price,
          imageBytes: _pickedBytes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('storage')
            ? 'Fotoğraf yüklenemedi. Supabase Storage politikasını kontrol edin.\n\n$e'
            : 'Kaydedilemedi: $e';
        AppToast.error(msg, title: 'Hata', duration: const Duration(seconds: 6));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.itemIndex == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                isAdd ? 'Ürün Ekle' : 'Ürün Düzenle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Image picker area
              _ImagePickerArea(
                bytes:       _pickedBytes,
                existingUrl: widget.initialImageUrl,
                onTap:       _pickImage,
              ),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: _nameCtrl,
                autofocus: isAdd,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'item_name'.tr,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Price field
              TextField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'price'.tr,
                  prefixText: '₺',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : Get.back,
                    child: Text('cancel'.tr),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text('save'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _IconPickerGrid
// ──────────────────────────────────────────────────────────────

class _IconPickerGrid extends StatelessWidget {
  const _IconPickerGrid({
    required this.selectedKey,
    required this.onSelect,
  });

  final String selectedKey;
  final void Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _kMenuIcons.length,
        itemBuilder: (_, i) {
          final opt      = _kMenuIcons[i];
          final selected = opt.key == selectedKey;

          return Tooltip(
            message: opt.label,
            child: GestureDetector(
              onTap: () => onSelect(opt.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                decoration: BoxDecoration(
                  color: selected ? _orange : _bg,
                  borderRadius: BorderRadius.circular(11),
                  border: selected
                      ? null
                      : Border.all(color: _border, width: 1),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x55FF9500),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  opt.icon,
                  size: 22,
                  color: selected ? Colors.white : _textSec,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _ImagePickerArea
// ──────────────────────────────────────────────────────────────

class _ImagePickerArea extends StatelessWidget {
  const _ImagePickerArea({
    required this.bytes,
    required this.existingUrl,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String?   existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget inner;

    if (bytes != null) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(bytes!, fit: BoxFit.cover,
            width: double.infinity, height: double.infinity),
      );
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          existingUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    } else {
      inner = _placeholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 155,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (bytes != null || (existingUrl?.isNotEmpty ?? false))
                ? _orange.withValues(alpha: 0.35)
                : _border,
            width: 1.5,
          ),
        ),
        child: inner,
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_rounded,
            size: 30,
            color: _orange,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Fotoğraf Ekle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textSec,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Galeriden seçmek için dokunun',
          style: TextStyle(fontSize: 11, color: _textSec),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _MenuCard
// ──────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.menu,
    required this.menuIndex,
    required this.onAddItem,
    required this.onEditMenu,
    required this.onDeleteMenu,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final Map<String, dynamic> menu;
  final int menuIndex;
  final VoidCallback onAddItem;
  final VoidCallback onEditMenu;
  final VoidCallback onDeleteMenu;
  final void Function(int, String, double, String?) onEditItem;
  final void Function(int) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final items    = menu['items'] as List;
    final menuName = menu['name'] as String;
    final menuId   = menu['id'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Menu header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Reactive icon — updates when user changes it
                Obx(() {
                  final key      = MenuService.to.getMenuIcon(menuId);
                  final iconData = _iconData(key);
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(_orange, Colors.white, 0.28)!,
                          _orange,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _orange.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(iconData, size: 18, color: Colors.white),
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menuName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        '${items.length} ürün',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.add_circle_outline_rounded,
                  color: AppTheme.successColor,
                  tooltip: 'add_item'.tr,
                  onTap: onAddItem,
                ),
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: _orange,
                  tooltip: 'edit_menu'.tr,
                  onTap: onEditMenu,
                ),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  tooltip: 'delete_menu'.tr,
                  onTap: onDeleteMenu,
                ),
              ],
            ),
          ),

          // ── Items list ───────────────────────────────
          if (items.isNotEmpty) ...[
            const Divider(height: 1, color: _border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _border),
              itemBuilder: (_, itemIndex) {
                final item      = items[itemIndex] as Map<String, dynamic>;
                final itemName  = item['name']  as String;
                final itemPrice = item['price'] as double;
                final imageUrl  = item['imageUrl'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Thumbnail or default icon
                      _ItemThumbnail(imageUrl: imageUrl),
                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                      ),

                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _orangeLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₺${itemPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      _IconBtn(
                        icon: Icons.edit_outlined,
                        color: _orange,
                        tooltip: 'edit_item'.tr,
                        onTap: () =>
                            onEditItem(itemIndex, itemName, itemPrice, imageUrl),
                        size: 18,
                      ),
                      _IconBtn(
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.errorColor,
                        tooltip: 'delete'.tr,
                        onTap: () => onDeleteItem(itemIndex),
                        size: 18,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _ItemThumbnail — small image or fallback icon in item rows
// ──────────────────────────────────────────────────────────────

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood_rounded, size: 18, color: _textSec),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _IconBtn
// ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}
