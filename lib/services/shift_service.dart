import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftService extends GetxService {
  static ShiftService get to => Get.find();

  final RxList<Map<String, dynamic>> shifts = <Map<String, dynamic>>[].obs;

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
        .channel('shifts_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shifts',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shift_breaks',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Lifecycle refresh ────────────────────────────────────────

  Future<void> refresh() => _load();

  // ── Load ────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('shifts')
          .select('*, shift_breaks(*)')
          .order('start_time', ascending: false);

      shifts.assignAll(rows.map(_rowToShift).toList());
    } catch (e) {
      if (kDebugMode) print('[ShiftService] load error: $e');
    }
  }

  Map<String, dynamic> _rowToShift(Map<String, dynamic> row) => {
        'id': row['id'] as String,
        'staffEmail': row['staff_email'] as String,
        'startTime': row['start_time'] as String,
        'endTime': row['end_time'] as String?,
        'date': (row['shift_date'] as String).substring(0, 10),
        'breaks': (row['shift_breaks'] as List)
            .map((b) => {
                  'id': b['id'] as int,
                  'start': b['start_time'] as String,
                  'end': b['end_time'] as String?,
                })
            .toList(),
      };

  // ── Shift actions ────────────────────────────────────────────

  Future<void> clockIn(String staffEmail) async {
    if (isClockedIn(staffEmail)) return;
    try {
      final now = DateTime.now();
      final row = await _db
          .from('shifts')
          .insert({
            'staff_email': staffEmail,
            'start_time': now.toIso8601String(),
            'shift_date': _dateFmt.format(now),
          })
          .select()
          .single();

      shifts.insert(0, {
        'id': row['id'] as String,
        'staffEmail': staffEmail,
        'startTime': row['start_time'] as String,
        'endTime': null,
        'date': _dateFmt.format(now),
        'breaks': <Map<String, dynamic>>[],
      });
    } catch (e) {
      if (kDebugMode) print('[ShiftService] clockIn error: $e');
    }
  }

  Future<void> clockOut(String staffEmail) async {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return;
    if (isOnBreak(staffEmail)) await endBreak(staffEmail);

    final shiftId = shifts[idx]['id'] as String;
    final now = DateTime.now().toIso8601String();
    shifts[idx]['endTime'] = now;
    shifts.refresh();

    try {
      await _db
          .from('shifts')
          .update({'end_time': now})
          .eq('id', shiftId);
    } catch (e) {
      if (kDebugMode) print('[ShiftService] clockOut error: $e');
    }
  }

  Future<void> startBreak(String staffEmail) async {
    final idx = _activeIdx(staffEmail);
    if (idx == -1 || isOnBreak(staffEmail)) return;

    final shiftId = shifts[idx]['id'] as String;
    final now = DateTime.now().toIso8601String();

    try {
      final row = await _db
          .from('shift_breaks')
          .insert({'shift_id': shiftId, 'start_time': now})
          .select()
          .single();

      final breaks =
          List<Map<String, dynamic>>.from(shifts[idx]['breaks'] as List);
      breaks.add({
        'id': row['id'] as int,
        'start': now,
        'end': null,
      });
      shifts[idx]['breaks'] = breaks;
      shifts.refresh();
    } catch (e) {
      if (kDebugMode) print('[ShiftService] startBreak error: $e');
    }
  }

  Future<void> endBreak(String staffEmail) async {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return;

    final breaks =
        List<Map<String, dynamic>>.from(shifts[idx]['breaks'] as List);
    final bi = breaks.indexWhere((b) => b['end'] == null);
    if (bi == -1) return;

    final breakId = breaks[bi]['id'] as int;
    final now = DateTime.now().toIso8601String();

    breaks[bi] = Map<String, dynamic>.from(breaks[bi])..['end'] = now;
    shifts[idx]['breaks'] = breaks;
    shifts.refresh();

    try {
      await _db
          .from('shift_breaks')
          .update({'end_time': now})
          .eq('id', breakId);
    } catch (e) {
      if (kDebugMode) print('[ShiftService] endBreak error: $e');
    }
  }

  // ── Queries ──────────────────────────────────────────────────

  int _activeIdx(String staffEmail) => shifts.indexWhere(
      (s) => s['staffEmail'] == staffEmail && s['endTime'] == null);

  bool isClockedIn(String staffEmail) => _activeIdx(staffEmail) != -1;

  bool isOnBreak(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return false;
    return (shifts[idx]['breaks'] as List).any((b) => (b as Map)['end'] == null);
  }

  Map<String, dynamic>? getActiveShift(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    return idx != -1 ? shifts[idx] : null;
  }

  List<Map<String, dynamic>> getShiftsForDate(DateTime date) {
    final d = _dateFmt.format(date);
    return shifts.where((s) => s['date'] == d).toList();
  }

  // ── Duration helpers ─────────────────────────────────────────

  int getWorkMinutes(Map<String, dynamic> shift) {
    final start = DateTime.parse(shift['startTime'] as String);
    final endStr = shift['endTime'] as String?;
    final end = endStr != null ? DateTime.parse(endStr) : DateTime.now();
    int total = end.difference(start).inMinutes;
    for (final b in (shift['breaks'] as List)) {
      final bm = b as Map;
      final bs = DateTime.parse(bm['start'] as String);
      final be = bm['end'] != null
          ? DateTime.parse(bm['end'] as String)
          : DateTime.now();
      total -= be.difference(bs).inMinutes;
    }
    return total.clamp(0, 9999);
  }

  int getBreakMinutes(Map<String, dynamic> shift) {
    int total = 0;
    for (final b in (shift['breaks'] as List)) {
      final bm = b as Map;
      final bs = DateTime.parse(bm['start'] as String);
      final be = bm['end'] != null
          ? DateTime.parse(bm['end'] as String)
          : DateTime.now();
      total += be.difference(bs).inMinutes;
    }
    return total;
  }

  String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}dk';
    return '${minutes ~/ 60}sa ${minutes % 60}dk';
  }
}
