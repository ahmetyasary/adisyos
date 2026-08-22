import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/models/app_role.dart';

class StaffService extends GetxService {
  static StaffService get to => Get.find();

  final RxList<Map<String, dynamic>> staffList = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> currentStaff = Rx(null);
  final RxBool isLoaded = false.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get _tenantId => _db.auth.currentUser!.id;

  bool get hasActiveStaff => currentStaff.value != null;
  String get currentStaffIdentifier =>
      currentStaff.value?['name'] as String? ?? '';

  /// App role for the active PIN session (defaults to garson).
  AppRole get currentStaffAppRole {
    final raw = currentStaff.value?['role'] as String? ?? 'garson';
    return AppRoleX.fromString(raw);
  }

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
        .channel('staff_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staff_profiles',
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> load() async {
    try {
      final rows = await _db
          .from('staff_profiles')
          .select()
          .eq('is_active', true)
          .order('created_at');
      staffList.assignAll(rows.map(_rowToStaff).toList());
      _refreshCurrentStaffFromList();
    } catch (e) {
      if (kDebugMode) print('[StaffService] load error: $e');
    } finally {
      isLoaded.value = true;
    }
  }

  void _refreshCurrentStaffFromList() {
    final id = currentStaff.value?['id'] as String?;
    if (id == null) return;
    final fresh = staffList.firstWhereOrNull((s) => s['id'] == id);
    if (fresh != null) {
      currentStaff.value = fresh;
    }
  }

  Map<String, dynamic> _rowToStaff(Map<String, dynamic> row) {
    final role = AppRoleX.fromString(row['role'] as String? ?? 'garson');
    return {
      'id': row['id'] as String,
      'name': row['name'] as String,
      'pin': row['pin'] as String,
      'role': role.staffDbValue,
      'isActive': row['is_active'] as bool? ?? true,
    };
  }

  void _err(String tag, Object e) {
    if (kDebugMode) print('[StaffService] $tag error: $e');
  }

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

  // addStaff must await: caller needs the real DB id immediately.
  Future<void> addStaff(
    String name,
    String pin, {
    AppRole role = AppRole.staff,
  }) async {
    try {
      final row = await _db
          .from('staff_profiles')
          .insert({
            'name': name.trim(),
            'pin': pin,
            'is_active': true,
            'tenant_id': _tenantId,
            'role': role.staffDbValue,
          })
          .select()
          .single();
      staffList.add(_rowToStaff(row));
    } catch (e) {
      _err('addStaff', e);
      rethrow;
    }
  }

  Future<void> updateStaff(
    String id, {
    required String name,
    required String pin,
    AppRole? role,
  }) async {
    final idx = staffList.indexWhere((s) => s['id'] == id);
    final roleValue = role?.staffDbValue ??
        (idx >= 0
            ? staffList[idx]['role'] as String? ?? 'garson'
            : 'garson');
    if (idx >= 0) {
      staffList[idx] = {
        ...staffList[idx],
        'name': name.trim(),
        'pin': pin,
        'role': roleValue,
      };
    }
    try {
      await _db.from('staff_profiles').update({
        'name': name.trim(),
        'pin': pin,
        'role': roleValue,
      }).eq('id', id);
    } catch (e) {
      _err('updateStaff', e);
    }
  }

  Future<void> deleteStaff(String id) async {
    staffList.removeWhere((s) => s['id'] == id);
    if (currentStaff.value?['id'] == id) clearCurrentStaff();
    try {
      await _db.from('staff_profiles').delete().eq('id', id);
    } catch (e) {
      _err('deleteStaff', e);
    }
  }
}
