import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks per-user work days. Each user (identified by their login email)
/// has their own active day independently — starting/ending is not shared.
class DayService extends GetxService {
  static DayService get to => Get.find();

  /// All currently active (not yet ended) days across all users.
  final RxList<Map<String, dynamic>> activeDays =
      <Map<String, dynamic>>[].obs;

  /// All historical days (active + ended), used by the admin day view.
  final RxList<Map<String, dynamic>> allDays =
      <Map<String, dynamic>>[].obs;

  final RxBool isLoading = false.obs;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _load();
    });
    _load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('day_status_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'day_status',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => Future.wait([_loadActive(), _loadAll()]);

  Future<void> _load() => Future.wait([_loadActive(), _loadAll()]);

  Future<void> _loadActive() async {
    try {
      final rows = await _db
          .from('day_status')
          .select()
          .isFilter('ended_at', null)
          .order('started_at', ascending: false);

      activeDays.assignAll(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (kDebugMode) print('[DayService] loadActive error: $e');
    }
  }

  Future<void> _loadAll() async {
    try {
      final rows = await _db
          .from('day_status')
          .select()
          .order('started_at', ascending: false)
          .limit(200);

      allDays.assignAll(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (kDebugMode) print('[DayService] loadAll error: $e');
    }
  }

  // ── Per-user queries ─────────────────────────────────────────

  bool isDayStartedBy(String email) =>
      activeDays.any((d) => d['started_by'] == email);

  Map<String, dynamic>? getActiveDayFor(String email) {
    try {
      return activeDays.firstWhere((d) => d['started_by'] == email);
    } catch (_) {
      return null;
    }
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<bool> startDay(String email) async {
    if (isDayStartedBy(email)) return true;
    isLoading.value = true;
    try {
      final now = DateTime.now();
      final row = await _db
          .from('day_status')
          .insert({
            'started_by': email,
            'started_at': now.toIso8601String(),
            'day_date': _dateFmt.format(now),
          })
          .select()
          .single();

      activeDays.add(Map<String, dynamic>.from(row));
      isLoading.value = false;
      return true;
    } catch (e) {
      if (kDebugMode) print('[DayService] startDay error: $e');
      isLoading.value = false;
      return false;
    }
  }

  /// Ends only the day that was started by [email]. Other users' days
  /// are unaffected.
  Future<bool> endDay(String email) async {
    final day = getActiveDayFor(email);
    if (day == null) return true;

    final id = day['id'];
    final now = DateTime.now().toIso8601String();

    // Optimistic in-memory update first.
    activeDays.removeWhere((d) => d['id'] == id);
    final idx = allDays.indexWhere((d) => d['id'] == id);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(allDays[idx]);
      updated['ended_by'] = email;
      updated['ended_at'] = now;
      allDays[idx] = updated;
      allDays.refresh();
    }

    // DB write in background.
    _db.from('day_status')
        .update({'ended_by': email, 'ended_at': now})
        .eq('id', id)
        .catchError((e) {
          if (kDebugMode) print('[DayService] endDay error: $e');
        });

    return true;
  }
}
