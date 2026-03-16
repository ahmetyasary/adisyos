import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ShiftService extends GetxService {
  static ShiftService get to => Get.find();

  final RxList<Map<String, dynamic>> shifts = <Map<String, dynamic>>[].obs;
  late String _filePath;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/shifts.json';
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final str = prefs.getString('shifts');
        if (str != null) {
          final list = json.decode(str) as List;
          shifts.assignAll(list.map(_parseShift));
        }
      } else {
        final file = File(_filePath);
        if (await file.exists()) {
          final str = await file.readAsString();
          final list = json.decode(str) as List;
          shifts.assignAll(list.map(_parseShift));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading shifts: $e');
    }
  }

  Map<String, dynamic> _parseShift(dynamic e) {
    final map = Map<String, dynamic>.from(e as Map);
    map['breaks'] = List<Map<String, dynamic>>.from(
      (map['breaks'] as List).map((b) => Map<String, dynamic>.from(b as Map)),
    );
    return map;
  }

  Future<void> _save() async {
    try {
      final str = json.encode(shifts);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shifts', str);
      } else {
        final file = File(_filePath);
        await file.writeAsString(str);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving shifts: $e');
    }
  }

  // ── Shift actions ─────────────────────────────────────────

  void clockIn(String staffEmail) {
    if (isClockedIn(staffEmail)) return;
    shifts.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'staffEmail': staffEmail,
      'startTime': DateTime.now().toIso8601String(),
      'endTime': null,
      'breaks': <Map<String, dynamic>>[],
      'date': _dateFmt.format(DateTime.now()),
    });
    _save();
  }

  void clockOut(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return;
    if (isOnBreak(staffEmail)) endBreak(staffEmail);
    shifts[idx]['endTime'] = DateTime.now().toIso8601String();
    shifts.refresh();
    _save();
  }

  void startBreak(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    if (idx == -1 || isOnBreak(staffEmail)) return;
    final breaks =
        List<Map<String, dynamic>>.from(shifts[idx]['breaks'] as List);
    breaks.add({'start': DateTime.now().toIso8601String(), 'end': null});
    shifts[idx]['breaks'] = breaks;
    shifts.refresh();
    _save();
  }

  void endBreak(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return;
    final breaks =
        List<Map<String, dynamic>>.from(shifts[idx]['breaks'] as List);
    final bi = breaks.indexWhere((b) => b['end'] == null);
    if (bi == -1) return;
    breaks[bi] = Map<String, dynamic>.from(breaks[bi])
      ..['end'] = DateTime.now().toIso8601String();
    shifts[idx]['breaks'] = breaks;
    shifts.refresh();
    _save();
  }

  // ── Queries ───────────────────────────────────────────────

  int _activeIdx(String staffEmail) => shifts.indexWhere(
      (s) => s['staffEmail'] == staffEmail && s['endTime'] == null);

  bool isClockedIn(String staffEmail) => _activeIdx(staffEmail) != -1;

  bool isOnBreak(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    if (idx == -1) return false;
    return (shifts[idx]['breaks'] as List)
        .any((b) => (b as Map)['end'] == null);
  }

  Map<String, dynamic>? getActiveShift(String staffEmail) {
    final idx = _activeIdx(staffEmail);
    return idx != -1 ? shifts[idx] : null;
  }

  List<Map<String, dynamic>> getShiftsForDate(DateTime date) {
    final d = _dateFmt.format(date);
    return shifts.where((s) => s['date'] == d).toList();
  }

  /// Net work minutes (total time minus break time).
  int getWorkMinutes(Map<String, dynamic> shift) {
    final start = DateTime.parse(shift['startTime'] as String);
    final endStr = shift['endTime'] as String?;
    final end =
        endStr != null ? DateTime.parse(endStr) : DateTime.now();
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
