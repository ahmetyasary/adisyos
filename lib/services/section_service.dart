import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SectionService extends GetxService {
  static SectionService get to => Get.find();

  final RxList<Map<String, dynamic>> sections = <Map<String, dynamic>>[].obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get _tenantId => _db.auth.currentUser!.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) load();
    });
    load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('sections_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sections',
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> load() async {
    try {
      final rows = await _db
          .from('sections')
          .select()
          .order('order_index')
          .order('created_at');
      sections.assignAll(rows.map(_rowToSection).toList());
    } catch (e) {
      if (kDebugMode) print('[SectionService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToSection(Map<String, dynamic> row) => {
        'id': row['id'] as String,
        'name': row['name'] as String,
        'orderIndex': row['order_index'] as int? ?? 0,
      };

  void _err(String tag, Object e) {
    if (kDebugMode) print('[SectionService] $tag error: $e');
  }

  Future<void> addSection(String name) async {
    try {
      final row = await _db
          .from('sections')
          .insert({
            'name': name.trim(),
            'order_index': sections.length,
            'tenant_id': _tenantId,
          })
          .select()
          .single();
      sections.add(_rowToSection(row));
    } catch (e) {
      _err('addSection', e);
      rethrow;
    }
  }

  Future<void> updateSection(String id, String name) async {
    final idx = sections.indexWhere((s) => s['id'] == id);
    if (idx >= 0) {
      sections[idx] = {...sections[idx], 'name': name.trim()};
    }
    try {
      await _db.from('sections')
          .update({'name': name.trim()})
          .eq('id', id);
    } catch (e) {
      _err('updateSection', e);
    }
  }

  Future<void> deleteSection(String id) async {
    sections.removeWhere((s) => s['id'] == id);
    try {
      await _db.from('sections')
          .delete()
          .eq('id', id);
    } catch (e) {
      _err('deleteSection', e);
    }
  }

  String? nameById(String? id) {
    if (id == null) return null;
    return sections.firstWhereOrNull((s) => s['id'] == id)?['name'] as String?;
  }
}
