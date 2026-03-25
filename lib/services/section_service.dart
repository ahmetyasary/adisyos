import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SectionService extends GetxService {
  static SectionService get to => Get.find();

  final RxList<Map<String, dynamic>> sections = <Map<String, dynamic>>[].obs;

  final _db = Supabase.instance.client;

  @override
  void onInit() {
    super.onInit();
    load();
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

  Future<void> addSection(String name) async {
    try {
      final row = await _db
          .from('sections')
          .insert({
            'name': name.trim(),
            'order_index': sections.length,
          })
          .select()
          .single();
      sections.add(_rowToSection(row));
    } catch (e) {
      if (kDebugMode) print('[SectionService] addSection error: $e');
      rethrow;
    }
  }

  Future<void> updateSection(String id, String name) async {
    try {
      await _db
          .from('sections')
          .update({'name': name.trim()})
          .eq('id', id);
      final idx = sections.indexWhere((s) => s['id'] == id);
      if (idx >= 0) sections[idx] = {...sections[idx], 'name': name.trim()};
    } catch (e) {
      if (kDebugMode) print('[SectionService] updateSection error: $e');
      rethrow;
    }
  }

  Future<void> deleteSection(String id) async {
    try {
      await _db.from('sections').delete().eq('id', id);
      sections.removeWhere((s) => s['id'] == id);
    } catch (e) {
      if (kDebugMode) print('[SectionService] deleteSection error: $e');
      rethrow;
    }
  }

  String? nameById(String? id) {
    if (id == null) return null;
    return sections.firstWhereOrNull((s) => s['id'] == id)?['name'] as String?;
  }
}
