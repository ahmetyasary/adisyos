import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffService extends GetxService {
  static StaffService get to => Get.find();

  final RxList<Map<String, dynamic>> staffList = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> currentStaff = Rx(null);

  final _db = Supabase.instance.client;

  bool get hasActiveStaff => currentStaff.value != null;
  String get currentStaffIdentifier =>
      currentStaff.value?['name'] as String? ?? '';

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await _db
          .from('staff_profiles')
          .select()
          .eq('is_active', true)
          .order('created_at');
      staffList.assignAll(rows.map(_rowToStaff).toList());
    } catch (e) {
      if (kDebugMode) print('[StaffService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToStaff(Map<String, dynamic> row) => {
        'id': row['id'] as String,
        'name': row['name'] as String,
        'pin': row['pin'] as String,
        'isActive': row['is_active'] as bool? ?? true,
      };

  /// Returns true if the PIN matches the given staff id.
  bool verifyPin(String staffId, String pin) {
    final staff = staffList.firstWhereOrNull((s) => s['id'] == staffId);
    if (staff == null) return false;
    return (staff['pin'] as String) == pin;
  }

  void setCurrentStaff(Map<String, dynamic> staff) {
    currentStaff.value = staff;
  }

  void clearCurrentStaff() {
    currentStaff.value = null;
  }

  Future<void> addStaff(String name, String pin) async {
    try {
      final row = await _db
          .from('staff_profiles')
          .insert({'name': name.trim(), 'pin': pin, 'is_active': true})
          .select()
          .single();
      staffList.add(_rowToStaff(row));
    } catch (e) {
      if (kDebugMode) print('[StaffService] addStaff error: $e');
      rethrow;
    }
  }

  Future<void> updateStaff(String id,
      {required String name, required String pin}) async {
    try {
      await _db
          .from('staff_profiles')
          .update({'name': name.trim(), 'pin': pin})
          .eq('id', id);
      final idx = staffList.indexWhere((s) => s['id'] == id);
      if (idx >= 0) {
        staffList[idx] = {...staffList[idx], 'name': name.trim(), 'pin': pin};
      }
    } catch (e) {
      if (kDebugMode) print('[StaffService] updateStaff error: $e');
      rethrow;
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await _db.from('staff_profiles').delete().eq('id', id);
      staffList.removeWhere((s) => s['id'] == id);
      if (currentStaff.value?['id'] == id) clearCurrentStaff();
    } catch (e) {
      if (kDebugMode) print('[StaffService] deleteStaff error: $e');
      rethrow;
    }
  }
}
