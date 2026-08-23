import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/table_service.dart';

class MenuService extends GetxService {
  static MenuService get to => Get.find();

  final RxList<Map<String, dynamic>> menus = <Map<String, dynamic>>[].obs;

  /// Reactive map of menu id → icon key, synced from DB.
  final RxMap<int, String> menuIcons = <int, String>{}.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  /// Soft-deleted menu item waiting for undo window / final commit.
  _PendingMenuItemDelete? _pendingItemDelete;
  Timer? _pendingItemDeleteTimer;

  String get _tenantId => _db.auth.currentUser!.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _loadMenus();
    });
    _loadMenus();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _commitPendingMenuItemDelete();
    _channel?.unsubscribe();
    super.onClose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('menu_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menus',
          callback: (_) => _loadMenus(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_items',
          callback: (_) => _loadMenus(),
        )
        .subscribe();
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _loadMenus();

  // ── Load ────────────────────────────────────────────────────

  Future<void> _loadMenus() async {
    try {
      List<dynamic> rows;
      try {
        rows = await _db
            .from('menus')
            .select(
              'id, name, icon_key, sort_order, menu_items(id, name, price, image_url, sort_order)',
            )
            .order('sort_order')
            .order('sort_order', referencedTable: 'menu_items');
      } catch (_) {
        try {
          rows = await _db
              .from('menus')
              .select('id, name, icon_key, menu_items(id, name, price, image_url)')
              .order('id');
        } catch (_) {
          rows = await _db
              .from('menus')
              .select('id, name, menu_items(id, name, price)')
              .order('id');
        }
      }
      final mapped = rows
          .cast<Map<String, dynamic>>()
          .map(_rowToMenu)
          .toList();
      mapped.sort((a, b) =>
          ((a['sortOrder'] as int?) ?? 0).compareTo((b['sortOrder'] as int?) ?? 0));
      for (final m in mapped) {
        final items = (m['items'] as List).cast<Map<String, dynamic>>();
        items.sort((a, b) =>
            ((a['sortOrder'] as int?) ?? 0).compareTo((b['sortOrder'] as int?) ?? 0));
      }
      menus.assignAll(mapped);
      _syncIconsFromMenus();
    } catch (e) {
      if (kDebugMode) print('[MenuService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToMenu(Map<String, dynamic> row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
        'iconKey': (row['icon_key'] as String?) ?? 'restaurant_menu',
        'sortOrder': (row['sort_order'] as num?)?.toInt() ?? 0,
        'items': ((row['menu_items'] ?? []) as List)
            .map((i) => {
                  'id': i['id'] as int,
                  'name': i['name'] as String,
                  'price': (i['price'] as num).toDouble(),
                  'imageUrl': i['image_url'] as String?,
                  'sortOrder': (i['sort_order'] as num?)?.toInt() ?? 0,
                })
            .toList(),
      };

  void _syncIconsFromMenus() {
    final map = <int, String>{};
    for (final m in menus) {
      map[m['id'] as int] = (m['iconKey'] as String?) ?? 'restaurant_menu';
    }
    menuIcons.assignAll(map);
  }

  void _err(String tag, Object e) {
    if (kDebugMode) print('[MenuService] $tag error: $e');
  }

  // ── Icon helpers ─────────────────────────────────────────────

  String getMenuIcon(int menuId) => menuIcons[menuId] ?? 'restaurant_menu';

  void setMenuIcon(int menuId, String iconKey) {
    menuIcons[menuId] = iconKey;
    final idx = menus.indexWhere((m) => m['id'] == menuId);
    if (idx != -1) {
      menus[idx]['iconKey'] = iconKey;
      menus.refresh();
    }
    _db.from('menus')
        .update({'icon_key': iconKey})
        .eq('id', menuId)
        .catchError((e) => _err('setMenuIcon', e));
  }

  // ── Image upload (Supabase Storage bucket: menu-images) ──────

  Future<String> uploadItemImage(Uint8List bytes, int itemId) async {
    final filename = 'item_$itemId.jpg';
    await _db.storage.from('menu-images').uploadBinary(
      filename,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return _db.storage.from('menu-images').getPublicUrl(filename);
  }

  // ── Seed defaults (first run) ────────────────────────────────

  Future<void> _seedDefaults() async {
    await addMenu('İçecekler');
    await addMenu('Tatlılar');

    final icIdx = menus.indexWhere((m) => m['name'] == 'İçecekler');
    if (icIdx != -1) {
      for (final item in [
        ('Americano', 30.0),
        ('Caffe Latte', 36.0),
        ('Caramel Latte', 40.0),
        ('Espresso', 25.0),
      ]) {
        await addMenuItem(icIdx, item.$1, item.$2);
      }
    }

    final ttIdx = menus.indexWhere((m) => m['name'] == 'Tatlılar');
    if (ttIdx != -1) {
      for (final item in [
        ('Cookie', 25.0),
        ('Tiramisu', 45.0),
        ('Banana Bread', 35.0),
      ]) {
        await addMenuItem(ttIdx, item.$1, item.$2);
      }
    }
  }

  // ── Mutations ────────────────────────────────────────────────

  /// Inserts a new menu with a default icon. Returns the new id or null.
  Future<int?> addMenu(String name) async {
    try {
      final row = await _db
          .from('menus')
          .insert({
            'name': name,
            'icon_key': 'restaurant_menu',
            'tenant_id': _tenantId,
            'sort_order': menus.length,
          })
          .select()
          .single();

      final id = row['id'] as int;
      menus.add({
        'id': id,
        'name': name,
        'iconKey': 'restaurant_menu',
        'sortOrder': menus.length,
        'items': <Map<String, dynamic>>[],
      });
      menuIcons[id] = 'restaurant_menu';
      return id;
    } catch (e) {
      _err('addMenu', e);
      return null;
    }
  }

  void updateMenu(int index, String name) {
    final id = menus[index]['id'] as int;
    menus[index]['name'] = name;
    menus.refresh();
    _db.from('menus')
        .update({'name': name})
        .eq('id', id)
        .catchError((e) => _err('updateMenu', e));
  }

  void removeMenu(int index) {
    final menu = menus[index];
    final id = menu['id'] as int;
    final items = List<Map<String, dynamic>>.from(
      (menu['items'] as List).cast<Map<String, dynamic>>(),
    );
    menus.removeAt(index);
    menuIcons.remove(id);
    _persistMenuOrder();
    // Remove active orders and inventory tracking for every item in this menu.
    for (final item in items) {
      final name = item['name'] as String;
      TableService.to.removeOrdersByItemName(name);
      InventoryService.to.removeTracking(name);
    }
    _db.from('menus')
        .delete()
        .eq('id', id)
        .catchError((e) => _err('removeMenu', e));
  }

  Future<void> addMenuItem(
    int menuIndex,
    String name,
    double price, {
    Uint8List? imageBytes,
  }) async {
    final menuId = menus[menuIndex]['id'] as int;
    final items = menus[menuIndex]['items'] as List;
    final row = await _db
        .from('menu_items')
        .insert({
          'menu_id': menuId,
          'name': name,
          'price': price,
          'tenant_id': _tenantId,
          'sort_order': items.length,
        })
        .select()
        .single();

    final itemId = row['id'] as int;
    String? imageUrl;

    if (imageBytes != null) {
      imageUrl = await uploadItemImage(imageBytes, itemId);
      _db.from('menu_items')
          .update({'image_url': imageUrl})
          .eq('id', itemId)
          .catchError((e) => _err('addMenuItem(image)', e));
    }

    (menus[menuIndex]['items'] as List).add({
      'id': itemId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'sortOrder': items.length,
    });
    menus.refresh();
  }

  Future<void> updateMenuItem(
    int menuIndex,
    int itemIndex,
    String name,
    double price, {
    Uint8List? imageBytes,
  }) async {
    final item =
        (menus[menuIndex]['items'] as List)[itemIndex] as Map<String, dynamic>;
    final itemId = item['id'] as int;

    // Update in-memory immediately.
    item['name'] = name;
    item['price'] = price;
    menus.refresh();

    final updateData = <String, dynamic>{'name': name, 'price': price};

    if (imageBytes != null) {
      final url = await uploadItemImage(imageBytes, itemId);
      item['imageUrl'] = url;
      menus.refresh();
      updateData['image_url'] = url;
    }

    _db.from('menu_items')
        .update(updateData)
        .eq('id', itemId)
        .catchError((e) => _err('updateMenuItem', e));
  }

  /// Soft-removes a menu item from the UI and schedules permanent deletion
  /// after [undoWindow] (orders + inventory + DB). Call [undoRemoveMenuItem]
  /// to restore within the window.
  void removeMenuItem(
    int menuIndex,
    int itemIndex, {
    Duration undoWindow = const Duration(seconds: 5),
  }) {
    if (menuIndex < 0 || menuIndex >= menus.length) return;
    final items = menus[menuIndex]['items'] as List;
    if (itemIndex < 0 || itemIndex >= items.length) return;

    // A previous soft-delete still pending → commit it first.
    _commitPendingMenuItemDelete();

    final item = Map<String, dynamic>.from(
      items[itemIndex] as Map<String, dynamic>,
    );
    items.removeAt(itemIndex);
    menus.refresh();

    _pendingItemDelete = _PendingMenuItemDelete(
      menuIndex: menuIndex,
      atIndex: itemIndex,
      item: item,
    );
    _pendingItemDeleteTimer?.cancel();
    _pendingItemDeleteTimer = Timer(undoWindow, _commitPendingMenuItemDelete);
  }

  /// Restores the last soft-deleted menu item, if the undo window is open.
  bool undoRemoveMenuItem() {
    final pending = _pendingItemDelete;
    if (pending == null) return false;
    _pendingItemDeleteTimer?.cancel();
    _pendingItemDeleteTimer = null;
    _pendingItemDelete = null;

    if (pending.menuIndex < 0 || pending.menuIndex >= menus.length) {
      return false;
    }
    final items = menus[pending.menuIndex]['items'] as List;
    final insertAt = pending.atIndex.clamp(0, items.length);
    items.insert(insertAt, Map<String, dynamic>.from(pending.item));
    menus.refresh();
    return true;
  }

  void _commitPendingMenuItemDelete() {
    final pending = _pendingItemDelete;
    _pendingItemDeleteTimer?.cancel();
    _pendingItemDeleteTimer = null;
    _pendingItemDelete = null;
    if (pending == null) return;

    final item = pending.item;
    final itemId = item['id'] as int;
    final itemName = item['name'] as String;

    if (pending.menuIndex >= 0 && pending.menuIndex < menus.length) {
      _persistItemOrder(pending.menuIndex);
    }

    TableService.to.removeOrdersByItemName(itemName);
    InventoryService.to.removeTracking(itemName);
    _db
        .from('menu_items')
        .delete()
        .eq('id', itemId)
        .catchError((e) => _err('removeMenuItem', e));
  }

  void reorderMenus(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final menu = menus.removeAt(oldIndex);
    menus.insert(newIndex, menu);
    menus.refresh();
    _persistMenuOrder();
  }

  void reorderItems(int menuIndex, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final items = menus[menuIndex]['items'] as List;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    menus.refresh();
    _persistItemOrder(menuIndex);
  }

  void _persistMenuOrder() {
    for (var i = 0; i < menus.length; i++) {
      menus[i]['sortOrder'] = i;
      _db
          .from('menus')
          .update({'sort_order': i})
          .eq('id', menus[i]['id'] as int)
          .catchError((e) => _err('persistMenuOrder', e));
    }
  }

  void _persistItemOrder(int menuIndex) {
    final items = menus[menuIndex]['items'] as List;
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      item['sortOrder'] = i;
      _db
          .from('menu_items')
          .update({'sort_order': i})
          .eq('id', item['id'] as int)
          .catchError((e) => _err('persistItemOrder', e));
    }
  }
}

class _PendingMenuItemDelete {
  _PendingMenuItemDelete({
    required this.menuIndex,
    required this.atIndex,
    required this.item,
  });

  final int menuIndex;
  final int atIndex;
  final Map<String, dynamic> item;
}
