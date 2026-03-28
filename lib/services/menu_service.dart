import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuService extends GetxService {
  static MenuService get to => Get.find();

  final RxList<Map<String, dynamic>> menus = <Map<String, dynamic>>[].obs;

  /// Reactive map of menu id → icon key, synced from DB.
  final RxMap<int, String> menuIcons = <int, String>{}.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

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
        // Full query: icon_key on menus + image_url on items.
        rows = await _db
            .from('menus')
            .select('id, name, icon_key, menu_items(id, name, price, image_url)')
            .order('id');
      } catch (_) {
        // Fallback: neither column added yet.
        rows = await _db
            .from('menus')
            .select('id, name, menu_items(id, name, price)')
            .order('id');
      }
      menus.assignAll(rows.cast<Map<String, dynamic>>().map(_rowToMenu).toList());
      _syncIconsFromMenus();
      if (menus.isEmpty) await _seedDefaults();
    } catch (e) {
      if (kDebugMode) print('[MenuService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToMenu(Map<String, dynamic> row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
        // Falls back to default if column not yet migrated
        'iconKey': (row['icon_key'] as String?) ?? 'restaurant_menu',
        'items': ((row['menu_items'] ?? []) as List)
            .map((i) => {
                  'id': i['id'] as int,
                  'name': i['name'] as String,
                  'price': (i['price'] as num).toDouble(),
                  'imageUrl': i['image_url'] as String?,
                })
            .toList(),
      };

  /// Syncs [menuIcons] directly from the menus list (already loaded from DB).
  void _syncIconsFromMenus() {
    final map = <int, String>{};
    for (final m in menus) {
      map[m['id'] as int] = (m['iconKey'] as String?) ?? 'restaurant_menu';
    }
    menuIcons.assignAll(map);
  }

  // ── Icon helpers ─────────────────────────────────────────────

  String getMenuIcon(int menuId) => menuIcons[menuId] ?? 'restaurant_menu';

  /// Updates icon both locally and in Supabase.
  Future<void> setMenuIcon(int menuId, String iconKey) async {
    menuIcons[menuId] = iconKey;
    final idx = menus.indexWhere((m) => m['id'] == menuId);
    if (idx != -1) {
      menus[idx]['iconKey'] = iconKey;
      menus.refresh();
    }
    try {
      await _db.from('menus').update({'icon_key': iconKey}).eq('id', menuId);
    } catch (e) {
      if (kDebugMode) print('[MenuService] setMenuIcon error: $e');
    }
  }

  // ── Image upload (Supabase Storage bucket: menu-images) ──────

  /// Uploads image bytes and returns the public URL.
  /// Throws [StorageException] on failure — callers must handle.
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
          .insert({'name': name, 'icon_key': 'restaurant_menu'})
          .select()
          .single();

      final id = row['id'] as int;
      menus.add({
        'id': id,
        'name': name,
        'iconKey': 'restaurant_menu',
        'items': <Map<String, dynamic>>[],
      });
      menuIcons[id] = 'restaurant_menu';
      return id;
    } catch (e) {
      if (kDebugMode) print('[MenuService] addMenu error: $e');
      return null;
    }
  }

  Future<void> updateMenu(int index, String name) async {
    final id = menus[index]['id'] as int;
    menus[index]['name'] = name;
    menus.refresh();
    try {
      await _db.from('menus').update({'name': name}).eq('id', id);
    } catch (e) {
      if (kDebugMode) print('[MenuService] updateMenu error: $e');
    }
  }

  Future<void> removeMenu(int index) async {
    final id = menus[index]['id'] as int;
    menus.removeAt(index);
    menuIcons.remove(id);
    try {
      await _db.from('menus').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) print('[MenuService] removeMenu error: $e');
    }
  }

  Future<void> addMenuItem(
    int menuIndex,
    String name,
    double price, {
    Uint8List? imageBytes,
  }) async {
    final menuId = menus[menuIndex]['id'] as int;
    final row = await _db
        .from('menu_items')
        .insert({'menu_id': menuId, 'name': name, 'price': price})
        .select()
        .single();

    final itemId = row['id'] as int;
    String? imageUrl;

    if (imageBytes != null) {
      imageUrl = await uploadItemImage(imageBytes, itemId); // throws on failure
      await _db
          .from('menu_items')
          .update({'image_url': imageUrl})
          .eq('id', itemId);
    }

    (menus[menuIndex]['items'] as List).add({
      'id': itemId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
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

    item['name'] = name;
    item['price'] = price;
    menus.refresh();

    final updateData = <String, dynamic>{'name': name, 'price': price};

    if (imageBytes != null) {
      final url = await uploadItemImage(imageBytes, itemId); // throws on failure
      item['imageUrl'] = url;
      menus.refresh();
      updateData['image_url'] = url;
    }

    await _db.from('menu_items').update(updateData).eq('id', itemId);
  }

  Future<void> removeMenuItem(int menuIndex, int itemIndex) async {
    final items = menus[menuIndex]['items'] as List;
    final itemId = (items[itemIndex] as Map<String, dynamic>)['id'] as int;
    items.removeAt(itemIndex);
    menus.refresh();
    try {
      await _db.from('menu_items').delete().eq('id', itemId);
    } catch (e) {
      if (kDebugMode) print('[MenuService] removeMenuItem error: $e');
    }
  }
}
