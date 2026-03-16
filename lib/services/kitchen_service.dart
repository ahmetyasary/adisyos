import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class KitchenService extends GetxService {
  static KitchenService get to => Get.find();

  final RxList<Map<String, dynamic>> tickets = <Map<String, dynamic>>[].obs;
  late String _filePath;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/kitchen_tickets.json';
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final str = prefs.getString('kitchen_tickets');
        if (str != null) {
          final list = json.decode(str) as List;
          tickets.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      } else {
        final file = File(_filePath);
        if (await file.exists()) {
          final str = await file.readAsString();
          final list = json.decode(str) as List;
          tickets.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading kitchen tickets: $e');
    }
  }

  Future<void> _save() async {
    try {
      final str = json.encode(tickets);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kitchen_tickets', str);
      } else {
        final file = File(_filePath);
        await file.writeAsString(str);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving kitchen tickets: $e');
    }
  }

  void addOrUpdateTicket({
    required int tableIndex,
    required String tableName,
    required String itemName,
    required int quantity,
  }) {
    final idx = tickets.indexWhere(
      (t) =>
          t['tableIndex'] == tableIndex &&
          t['itemName'] == itemName &&
          t['status'] != 'ready',
    );
    if (idx != -1) {
      tickets[idx]['quantity'] = quantity;
      tickets.refresh();
    } else {
      tickets.add({
        'id': '${tableIndex}_${itemName}_${DateTime.now().millisecondsSinceEpoch}',
        'tableIndex': tableIndex,
        'tableName': tableName,
        'itemName': itemName,
        'quantity': quantity,
        'status': 'pending',
        'orderedAt': DateTime.now().toIso8601String(),
      });
    }
    _save();
  }

  void advanceStatus(String ticketId) {
    final idx = tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    final current = tickets[idx]['status'] as String;
    if (current == 'pending') {
      tickets[idx]['status'] = 'preparing';
    } else if (current == 'preparing') {
      tickets[idx]['status'] = 'ready';
    }
    tickets.refresh();
    _save();
  }

  void removeTicketsForTable(int tableIndex) {
    tickets.removeWhere((t) => t['tableIndex'] == tableIndex);
    _save();
  }

  void removeTicketForItem(int tableIndex, String itemName) {
    tickets.removeWhere(
      (t) => t['tableIndex'] == tableIndex && t['itemName'] == itemName,
    );
    _save();
  }

  void clearReadyTickets() {
    tickets.removeWhere((t) => t['status'] == 'ready');
    _save();
  }

  List<Map<String, dynamic>> get pendingTickets =>
      tickets.where((t) => t['status'] == 'pending').toList();

  List<Map<String, dynamic>> get preparingTickets =>
      tickets.where((t) => t['status'] == 'preparing').toList();

  List<Map<String, dynamic>> get readyTickets =>
      tickets.where((t) => t['status'] == 'ready').toList();
}
