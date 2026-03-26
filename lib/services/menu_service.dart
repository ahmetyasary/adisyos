import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuService extends GetxService {
  static MenuService get to => Get.find();

  final RxList<Map<String, dynamic>> menus = <Map<String, dynamic>>[].obs;

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

  // ── Load ────────────────────────────────────────────────────

  Future<void> _loadMenus() async {
    try {
      final rows = await _db
          .from('menus')
          .select('id, name, menu_items(id, name, price)')
          .order('id');

      menus.assignAll(rows.map(_rowToMenu).toList());

      if (menus.isEmpty) await _seedDefaults();
    } catch (e) {
      if (kDebugMode) print('[MenuService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToMenu(Map<String, dynamic> row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
        'items': (row['menu_items'] as List)
            .map((i) => {
                  'id': i['id'] as int,
                  'name': i['name'] as String,
                  'price': (i['price'] as num).toDouble(),
                })
            .toList(),
      };

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

  Future<void> addMenu(String name) async {
    try {
      final row = await _db
          .from('menus')
          .insert({'name': name})
          .select()
          .single();

      menus.add({
        'id': row['id'] as int,
        'name': name,
        'items': <Map<String, dynamic>>[],
      });
    } catch (e) {
      if (kDebugMode) print('[MenuService] addMenu error: $e');
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
    try {
      // menu_items cascade-delete via FK
      await _db.from('menus').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) print('[MenuService] removeMenu error: $e');
    }
  }

  Future<void> addMenuItem(int menuIndex, String name, double price) async {
    final menuId = menus[menuIndex]['id'] as int;
    try {
      final row = await _db
          .from('menu_items')
          .insert({'menu_id': menuId, 'name': name, 'price': price})
          .select()
          .single();

      (menus[menuIndex]['items'] as List).add({
        'id': row['id'] as int,
        'name': name,
        'price': price,
      });
      menus.refresh();
    } catch (e) {
      if (kDebugMode) print('[MenuService] addMenuItem error: $e');
    }
  }

  Future<void> updateMenuItem(
    int menuIndex,
    int itemIndex,
    String name,
    double price,
  ) async {
    final item =
        (menus[menuIndex]['items'] as List)[itemIndex] as Map<String, dynamic>;
    final itemId = item['id'] as int;

    item['name'] = name;
    item['price'] = price;
    menus.refresh();

    try {
      await _db
          .from('menu_items')
          .update({'name': name, 'price': price})
          .eq('id', itemId);
    } catch (e) {
      if (kDebugMode) print('[MenuService] updateMenuItem error: $e');
    }
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
