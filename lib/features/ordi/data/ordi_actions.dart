import 'package:get/get.dart';

import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/features/ordi/data/ordi_snapshot.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/utils/app_haptics.dart';

class OrdiToolCall {
  const OrdiToolCall(this.name, this.args);

  final String name;
  final Map<String, dynamic> args;

  static OrdiToolCall? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'] as String? ?? '';
    if (name.isEmpty) return null;
    final args = raw['args'] ?? raw['arguments'];
    return OrdiToolCall(
      name,
      args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
    );
  }
}

class OrdiRunSplit {
  const OrdiRunSplit({
    required this.adds,
    required this.changes,
    required this.blocked,
  });

  final List<OrdiToolCall> adds;
  final List<OrdiToolCall> changes;
  final List<String> blocked;
}

/// Executes Ordi write tools via existing GetX services.
///
/// Adds run immediately. Changes are held for a yes/no. Deletes are refused.
class OrdiActionRunner {
  static const addOps = {
    'create_table',
    'add_menu_category',
    'add_menu_item',
    'add_section',
    'add_staff',
    'add_order',
    'set_stock_new',
    'start_day',
    'clock_in',
    'start_break',
  };

  static const changeOps = {
    'rename_table',
    'rename_section',
    'rename_menu_category',
    'update_menu_item',
    'set_stock',
    'apply_discount',
    'take_payment',
    'partial_payment',
    'move_orders',
    'end_day',
    'clock_out',
    'end_break',
    'set_company_name',
    'set_currency',
    'update_staff',
    'advance_kitchen',
  };

  static const _deleteHints = [
    'delete',
    'remove',
    'clear',
    'sil',
  ];

  static OrdiRunSplit split(List<OrdiToolCall> calls) {
    final adds = <OrdiToolCall>[];
    final changes = <OrdiToolCall>[];
    final blocked = <String>[];
    for (final c in calls) {
      final n = c.name.toLowerCase();
      if (_deleteHints.any(n.contains)) {
        blocked.add(c.name);
        continue;
      }
      if (c.name == 'set_stock' || c.name == 'set_stock_new') {
        final item = _str(c.args['item'] ?? c.args['name']);
        final tracked = Get.isRegistered<InventoryService>() &&
            InventoryService.to.isTracked(item);
        if (tracked) {
          changes.add(OrdiToolCall('set_stock', c.args));
        } else {
          adds.add(OrdiToolCall('set_stock_new', c.args));
        }
        continue;
      }
      if (addOps.contains(c.name)) {
        adds.add(c);
      } else if (changeOps.contains(c.name)) {
        changes.add(c);
      } else {
        blocked.add(c.name);
      }
    }
    return OrdiRunSplit(adds: adds, changes: changes, blocked: blocked);
  }

  static Future<String> run(List<OrdiToolCall> calls) async {
    if (calls.isEmpty) return '';
    final lines = <String>[];
    for (final call in calls) {
      try {
        lines.add('• ${await _runOne(call)}');
      } catch (e) {
        lines.add('• İşlem başarısız: $e');
      }
    }
    return lines.join('\n');
  }

  static String confirmPrompt(List<OrdiToolCall> changes) {
    final lines = [for (final c in changes) '• ${_describe(c)}'];
    return 'Bu değişiklikleri onaylıyor musunuz?\n'
        '${lines.join('\n')}\n\n'
        'Evet / Hayır yazmanız yeterli.';
  }

  static String _describe(OrdiToolCall c) {
    final a = c.args;
    return switch (c.name) {
      'rename_table' =>
        '“${_str(a['table'])}” masasının adı “${_str(a['newName'])}” olsun',
      'rename_section' =>
        '“${_str(a['section'])}” bölümünün adı “${_str(a['newName'])}” olsun',
      'rename_menu_category' =>
        '“${_str(a['category'])}” kategorisi “${_str(a['newName'])}” olsun',
      'update_menu_item' =>
        '“${_str(a['name'])}” ürünü güncellensin'
            '${_str(a['newName']).isEmpty ? '' : ' (yeni ad: ${_str(a['newName'])})'}'
            '${a['price'] == null ? '' : ' (fiyat: ${a['price']})'}',
      'set_stock' =>
        '“${_str(a['item'] ?? a['name'])}” stoğu ${a['count'] ?? a['stock']} olsun',
      'apply_discount' =>
        '${_str(a['table'])} masasına %${a['percent'] ?? a['percentage']} indirim',
      'take_payment' =>
        '${_str(a['table'])} masası ${_payLabel(a['method'])} ile kapatılsın',
      'partial_payment' =>
        '${_str(a['table'])} / ${_str(a['item'])} ×${a['qty'] ?? a['quantity']} '
            '${_payLabel(a['method'])} kısmi ödensin',
      'move_orders' =>
        'Siparişler ${_str(a['from'])} → ${_str(a['to'])} taşınsın',
      'end_day' => 'Çalışma günü kapatılsın',
      'clock_out' => '${_str(a['staff'])} vardiyadan çıksın',
      'end_break' => '${_str(a['staff'])} molası bitsin',
      'set_company_name' => 'İşletme adı “${_str(a['name'])}” olsun',
      'set_currency' => 'Para birimi ${ _str(a['symbol'])} olsun',
      'update_staff' => '${_str(a['staff'] ?? a['name'])} personeli güncellensin',
      'advance_kitchen' =>
        '${_str(a['table'])} / ${_str(a['item'])} mutfak durumu ilerlesin',
      _ => c.name,
    };
  }

  static Future<String> _runOne(OrdiToolCall call) async {
    switch (call.name) {
      case 'create_table':
        return _createTable(call.args);
      case 'add_menu_category':
        return _addCategory(call.args);
      case 'add_menu_item':
        return _addItem(call.args);
      case 'add_section':
        return _addSection(call.args);
      case 'add_staff':
        return _addStaff(call.args);
      case 'add_order':
        return _addOrder(call.args);
      case 'set_stock_new':
      case 'set_stock':
        return _setStock(call.args);
      case 'start_day':
        return _startDay();
      case 'clock_in':
        return _clock(call.args, inShift: true);
      case 'start_break':
        return _break(call.args, start: true);
      case 'rename_table':
        return _renameTable(call.args);
      case 'rename_section':
        return _renameSection(call.args);
      case 'rename_menu_category':
        return _renameCategory(call.args);
      case 'update_menu_item':
        return _updateItem(call.args);
      case 'apply_discount':
        return _discount(call.args);
      case 'take_payment':
        return _pay(call.args);
      case 'partial_payment':
        return _partialPay(call.args);
      case 'move_orders':
        return _move(call.args);
      case 'end_day':
        return _endDay();
      case 'clock_out':
        return _clock(call.args, inShift: false);
      case 'end_break':
        return _break(call.args, start: false);
      case 'set_company_name':
        return _company(call.args);
      case 'set_currency':
        return _currency(call.args);
      case 'update_staff':
        return _updateStaff(call.args);
      case 'advance_kitchen':
        return _kitchen(call.args);
      default:
        return 'Bu işleme izin yok.';
    }
  }

  // ── Adds ───────────────────────────────────────────────────────────────

  static Future<String> _createTable(Map<String, dynamic> args) async {
    if (!Get.isRegistered<TableService>()) return 'Masa servisi yok.';
    var name = _str(args['name']);
    if (name.isEmpty) {
      name = (OrdiSnapshot.build()['masalar']
              as Map?)?['onerilenSonrakiMasaAdi'] as String? ??
          'Masa ${TableService.to.tables.length + 1}';
    }
    if (name.length > 40) name = name.substring(0, 40);
    String? sectionId;
    final sectionName = _str(args['sectionName'] ?? args['section']);
    if (sectionName.isNotEmpty) {
      sectionId = _sectionId(sectionName);
      if (sectionId == null) return '“$sectionName” bölümü yok. Masa eklenmedi.';
    }
    final err = await TableService.to.addTable(name, sectionId: sectionId);
    return err ?? '“$name” masası oluşturuldu.';
  }

  static Future<String> _addCategory(Map<String, dynamic> args) async {
    if (!Get.isRegistered<MenuService>()) return 'Menü servisi yok.';
    final name = _str(args['name'] ?? args['category']);
    if (name.isEmpty) return 'Kategori adı gerekli.';
    if (_menuIndex(name) != -1) return '“$name” kategorisi zaten var.';
    final id = await MenuService.to.addMenu(name);
    return id == null ? 'Kategori eklenemedi.' : '“$name” kategorisi eklendi.';
  }

  static Future<String> _addItem(Map<String, dynamic> args) async {
    if (!Get.isRegistered<MenuService>()) return 'Menü servisi yok.';
    final category = _str(args['category'] ?? args['categoryName']);
    final name = _str(args['name'] ?? args['item']);
    final price = _price(args['price']);
    if (name.isEmpty) return 'Ürün adı gerekli.';
    if (price == null || price <= 0 || price > 100000) {
      return 'Geçerli bir fiyat gerekli.';
    }
    if (category.isEmpty) return 'Kategori adı gerekli.';
    var idx = _menuIndex(category);
    if (idx == -1) {
      final id = await MenuService.to.addMenu(category);
      if (id == null) return '“$category” kategorisi oluşturulamadı.';
      idx = MenuService.to.menus.indexWhere((m) => m['id'] == id);
    }
    if (idx == -1) return 'Kategori bulunamadı.';
    final items = (MenuService.to.menus[idx]['items'] as List?) ?? const [];
    if (items.any((i) => _eq((i as Map)['name'], name))) {
      return '“$name” bu kategoride zaten var.';
    }
    await MenuService.to.addMenuItem(idx, name, price);
    return '“$name” $category altına ${ordiMoney(price)} ile eklendi.';
  }

  static Future<String> _addSection(Map<String, dynamic> args) async {
    if (!Get.isRegistered<SectionService>()) return 'Bölüm servisi yok.';
    final name = _str(args['name']);
    if (name.isEmpty) return 'Bölüm adı gerekli.';
    if (_sectionId(name) != null) return '“$name” bölümü zaten var.';
    await SectionService.to.addSection(name);
    return '“$name” bölümü eklendi.';
  }

  static Future<String> _addStaff(Map<String, dynamic> args) async {
    if (!Get.isRegistered<StaffService>()) return 'Personel servisi yok.';
    final name = _str(args['name'] ?? args['staff']);
    final pin = _str(args['pin']);
    if (name.isEmpty) return 'Personel adı gerekli.';
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return '4 haneli PIN gerekli (ör. “Ali 4821 ekle”).';
    }
    await StaffService.to.addStaff(name, pin);
    return '“$name” personeli eklendi.';
  }

  static Future<String> _addOrder(Map<String, dynamic> args) async {
    if (!Get.isRegistered<TableService>()) return 'Masa servisi yok.';
    final table = _str(args['table']);
    final item = _str(args['item'] ?? args['name']);
    final qty = (_int(args['qty'] ?? args['quantity']) ?? 1).clamp(1, 50);
    final ti = _tableIndex(table);
    if (ti == -1) return '“$table” masası bulunamadı.';
    final found = _menuItem(item);
    if (found == null) return '“$item” menüde yok.';
    for (var i = 0; i < qty; i++) {
      TableService.to.addOrder(ti, found.$1, found.$2);
    }
    return '“$table” masasına $qty × ${found.$1} eklendi.';
  }

  static Future<String> _setStock(Map<String, dynamic> args) async {
    if (!Get.isRegistered<InventoryService>()) return 'Stok servisi yok.';
    final item = _str(args['item'] ?? args['name']);
    final count = _int(args['count'] ?? args['stock']);
    if (item.isEmpty || count == null || count < 0) {
      return 'Ürün adı ve stok adedi gerekli.';
    }
    InventoryService.to.setStock(item, count);
    return '“$item” stoğu $count olarak ayarlandı.';
  }

  static Future<String> _startDay() async {
    if (!Get.isRegistered<DayService>()) return 'Gün servisi yok.';
    final who = _who;
    if (who.isEmpty) return 'Oturum bulunamadı.';
    if (DayService.to.isDayStartedBy(who)) return 'Gün zaten açık.';
    final ok = await DayService.to.startDay(who);
    return ok ? 'Gün başlatıldı.' : 'Gün başlatılamadı.';
  }

  static Future<String> _clock(Map<String, dynamic> args, {required bool inShift}) async {
    if (!Get.isRegistered<ShiftService>()) return 'Vardiya servisi yok.';
    final staff = _staffName(args);
    if (staff.isEmpty) return 'Personel adı gerekli.';
    if (inShift) {
      await ShiftService.to.clockIn(staff);
      return '$staff vardiyaya girdi.';
    }
    await ShiftService.to.clockOut(staff);
    return '$staff vardiyadan çıktı.';
  }

  static Future<String> _break(Map<String, dynamic> args, {required bool start}) async {
    if (!Get.isRegistered<ShiftService>()) return 'Vardiya servisi yok.';
    final staff = _staffName(args);
    if (staff.isEmpty) return 'Personel adı gerekli.';
    if (start) {
      await ShiftService.to.startBreak(staff);
      return '$staff molaya çıktı.';
    }
    await ShiftService.to.endBreak(staff);
    return '$staff molası bitti.';
  }

  // ── Changes ────────────────────────────────────────────────────────────

  static Future<String> _renameTable(Map<String, dynamic> args) async {
    final ti = _tableIndex(_str(args['table']));
    if (ti == -1) return 'Masa bulunamadı.';
    final newName = _str(args['newName']);
    if (newName.isEmpty) return 'Yeni ad gerekli.';
    final sectionName = _str(args['sectionName'] ?? args['section']);
    if (sectionName.isNotEmpty) {
      final sid = _sectionId(sectionName);
      if (sid == null) return '“$sectionName” bölümü yok.';
      TableService.to.updateTable(ti, newName, sectionId: sid, sectionChanged: true);
    } else {
      TableService.to.updateTableName(ti, newName);
    }
    return 'Masa adı “$newName” olarak güncellendi.';
  }

  static Future<String> _renameSection(Map<String, dynamic> args) async {
    final id = _sectionId(_str(args['section'] ?? args['name']));
    if (id == null) return 'Bölüm bulunamadı.';
    final newName = _str(args['newName']);
    if (newName.isEmpty) return 'Yeni ad gerekli.';
    await SectionService.to.updateSection(id, newName);
    return 'Bölüm adı “$newName” oldu.';
  }

  static Future<String> _renameCategory(Map<String, dynamic> args) async {
    final idx = _menuIndex(_str(args['category'] ?? args['name']));
    if (idx == -1) return 'Kategori bulunamadı.';
    final newName = _str(args['newName']);
    if (newName.isEmpty) return 'Yeni ad gerekli.';
    MenuService.to.updateMenu(idx, newName);
    return 'Kategori adı “$newName” oldu.';
  }

  static Future<String> _updateItem(Map<String, dynamic> args) async {
    final category = _str(args['category']);
    final name = _str(args['name']);
    final loc = _itemIndex(category, name);
    if (loc == null) return 'Ürün bulunamadı.';
    final newName = _str(args['newName']);
    final price = _price(args['price'] ?? args['newPrice']);
    final menu = MenuService.to.menus[loc.$1];
    final item = (menu['items'] as List)[loc.$2] as Map;
    final finalName = newName.isEmpty ? item['name'] as String : newName;
    final finalPrice = price ?? (item['price'] as num).toDouble();
    await MenuService.to.updateMenuItem(loc.$1, loc.$2, finalName, finalPrice);
    return '“$finalName” ${ordiMoney(finalPrice)} olarak güncellendi.';
  }

  static Future<String> _discount(Map<String, dynamic> args) async {
    final ti = _tableIndex(_str(args['table']));
    if (ti == -1) return 'Masa bulunamadı.';
    final pct = _price(args['percent'] ?? args['percentage']);
    if (pct == null || pct < 0 || pct > 100) return 'Geçerli bir yüzde gerekli.';
    TableService.to.applyDiscount(ti, pct);
    return '${_str(args['table'])} masasına %${pct.toStringAsFixed(0)} indirim uygulandı.';
  }

  static Future<String> _pay(Map<String, dynamic> args) async {
    final ti = _tableIndex(_str(args['table']));
    if (ti == -1) return 'Masa bulunamadı.';
    final method = _payMethod(args['method']);
    TableService.to.recordPayment(ti, paymentMethod: method);
    return '${_str(args['table'])} ${_payLabel(method)} ile kapatıldı.';
  }

  static Future<String> _partialPay(Map<String, dynamic> args) async {
    final ti = _tableIndex(_str(args['table']));
    if (ti == -1) return 'Masa bulunamadı.';
    final item = _str(args['item'] ?? args['name']);
    final qty = _int(args['qty'] ?? args['quantity']) ?? 1;
    final method = _payMethod(args['method']);
    await TableService.to.recordPartialPaymentUnits(
      ti,
      item,
      qty,
      paymentMethod: method,
    );
    AppHaptics.success();
    return '${_str(args['table'])} / $item ×$qty ${_payLabel(method)} ödendi.';
  }

  static Future<String> _move(Map<String, dynamic> args) async {
    final from = _tableIndex(_str(args['from'] ?? args['fromTable']));
    final to = _tableIndex(_str(args['to'] ?? args['toTable']));
    if (from == -1 || to == -1) return 'Masa bulunamadı.';
    TableService.to.moveAllOrdersToTable(from, to);
    return 'Siparişler ${_str(args['from'])} → ${_str(args['to'])} taşındı.';
  }

  static Future<String> _endDay() async {
    if (!Get.isRegistered<DayService>()) return 'Gün servisi yok.';
    final who = _who;
    if (who.isEmpty) return 'Oturum bulunamadı.';
    final hasOrders =
        TableService.to.tables.any((t) => t['isOccupied'] == true);
    if (hasOrders) {
      return 'Açık masa varken gün bitmez. Önce masaları kapatın.';
    }
    final ok = await DayService.to.endDay(who);
    return ok ? 'Gün kapatıldı.' : 'Gün kapatılamadı.';
  }

  static Future<String> _company(Map<String, dynamic> args) async {
    if (!Get.isRegistered<SettingsService>()) return 'Ayar servisi yok.';
    final name = _str(args['name']);
    if (name.isEmpty) return 'İşletme adı gerekli.';
    await SettingsService.to.save(newCompanyName: name);
    return 'İşletme adı “$name” olarak kaydedildi.';
  }

  static Future<String> _currency(Map<String, dynamic> args) async {
    if (!Get.isRegistered<SettingsService>()) return 'Ayar servisi yok.';
    final symbol = _str(args['symbol'] ?? args['currency']);
    if (symbol.isEmpty) return 'Sembol gerekli (₺, €, \$).';
    await SettingsService.to.setCurrency(symbol);
    return 'Para birimi $symbol oldu.';
  }

  static Future<String> _updateStaff(Map<String, dynamic> args) async {
    final staff = _findStaff(_str(args['staff'] ?? args['name']));
    if (staff == null) return 'Personel bulunamadı.';
    final newName = _str(args['newName']);
    final pin = _str(args['pin']);
    await StaffService.to.updateStaff(
      staff['id'] as String,
      name: newName.isEmpty ? staff['name'] as String : newName,
      pin: pin.isEmpty ? staff['pin'] as String : pin,
    );
    return '${staff['name']} güncellendi.';
  }

  static Future<String> _kitchen(Map<String, dynamic> args) async {
    if (!Get.isRegistered<KitchenService>()) return 'Mutfak servisi yok.';
    final table = _str(args['table']).toLowerCase();
    final item = _str(args['item'] ?? args['name']).toLowerCase();
    final ticket = KitchenService.to.tickets.firstWhereOrNull((t) {
      final tn = (t['tableName'] as String? ?? '').toLowerCase();
      final it = (t['itemName'] as String? ?? '').toLowerCase();
      return tn == table && (item.isEmpty || it == item);
    });
    if (ticket == null) return 'Mutfak bileti bulunamadı.';
    if ((ticket['status'] as String?) == 'ready') {
      return 'Bu bilet zaten hazır.';
    }
    KitchenService.to.advanceStatus(ticket['id'] as String);
    return '${ticket['tableName']} / ${ticket['itemName']} durumu ilerletildi.';
  }

  // ── Lookups ────────────────────────────────────────────────────────────

  static String get _who {
    if (Get.isRegistered<StaffService>()) {
      final n = StaffService.to.currentStaffIdentifier;
      if (n.isNotEmpty) return n;
    }
    return AuthController.to.user.value?.email ?? '';
  }

  static int _tableIndex(String name) {
    if (!Get.isRegistered<TableService>() || name.isEmpty) return -1;
    final n = name.trim().toLowerCase();
    final tables = TableService.to.tables;
    var i = tables.indexWhere((t) => (t['name'] as String).toLowerCase() == n);
    if (i != -1) return i;
    i = tables.indexWhere(
      (t) => (t['name'] as String).toLowerCase().replaceAll('masa ', '') ==
          n.replaceAll('masa ', ''),
    );
    return i;
  }

  static int _menuIndex(String name) {
    if (!Get.isRegistered<MenuService>() || name.isEmpty) return -1;
    final n = name.toLowerCase();
    return MenuService.to.menus
        .indexWhere((m) => (m['name'] as String).toLowerCase() == n);
  }

  static (int, int)? _itemIndex(String category, String name) {
    final mi = category.isEmpty
        ? -2
        : _menuIndex(category);
    final n = name.toLowerCase();
    if (mi >= 0) {
      final items = MenuService.to.menus[mi]['items'] as List;
      final ii = items.indexWhere((i) => _eq((i as Map)['name'], n));
      if (ii != -1) return (mi, ii);
    }
    for (var m = 0; m < MenuService.to.menus.length; m++) {
      final items = MenuService.to.menus[m]['items'] as List;
      final ii = items.indexWhere((i) => _eq((i as Map)['name'], n));
      if (ii != -1) return (m, ii);
    }
    return null;
  }

  static (String, double)? _menuItem(String name) {
    final loc = _itemIndex('', name);
    if (loc == null) return null;
    final item =
        (MenuService.to.menus[loc.$1]['items'] as List)[loc.$2] as Map;
    return (item['name'] as String, (item['price'] as num).toDouble());
  }

  static String? _sectionId(String name) {
    if (!Get.isRegistered<SectionService>() || name.isEmpty) return null;
    final n = name.toLowerCase();
    return SectionService.to.sections
        .firstWhereOrNull((s) => (s['name'] as String).toLowerCase() == n)
        ?['id'] as String?;
  }

  static Map<String, dynamic>? _findStaff(String name) {
    if (!Get.isRegistered<StaffService>() || name.isEmpty) return null;
    final n = name.toLowerCase();
    return StaffService.to.staffList
        .firstWhereOrNull((s) => (s['name'] as String).toLowerCase() == n);
  }

  static String _staffName(Map<String, dynamic> args) {
    final n = _str(args['staff'] ?? args['name']);
    if (n.isNotEmpty) return n;
    return Get.isRegistered<StaffService>()
        ? StaffService.to.currentStaffIdentifier
        : '';
  }

  static bool _eq(Object? a, String b) =>
      (a?.toString() ?? '').toLowerCase() == b.toLowerCase();

  static String _str(Object? v) => (v?.toString() ?? '').trim();

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(_str(v));
  }

  static double? _price(Object? v) {
    if (v is num) return v.toDouble();
    if (v is! String) return null;
    var s = v.trim().replaceAll('₺', '');
    s = s.replaceAll(RegExp(r'\s*(tl|TL)$'), '').trim();
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s);
  }

  static String _payMethod(Object? v) {
    final s = _str(v).toLowerCase();
    if (s.contains('kart') || s.contains('card') || s.contains('credit')) {
      return 'card';
    }
    return 'cash';
  }

  static String _payLabel(Object? v) {
    final m = _payMethod(v);
    return m == 'card' ? 'kart' : 'nakit';
  }
}

/// Offline parse of the most common write commands.
class OrdiIntentParser {
  static List<OrdiToolCall> parse(String question, Map<String, dynamic> snapshot) {
    final q = question.trim();
    if (q.isEmpty) return const [];
    final lower = q.toLowerCase();
    if (_isDelete(lower)) return const [];

    final item = _parseAddItem(q);
    if (item != null) return [item];

    if (_looksLikeCreateTable(lower)) {
      var name = '';
      if (!lower.contains('sıradaki') && !lower.contains('siradaki')) {
        final named = RegExp(
          r'(?:masa(?:sı)?|ad[ıi])\s*[:=]?\s*["“]?([^"”\n,]{1,40})["”]?',
          caseSensitive: false,
        ).firstMatch(q);
        if (named != null) {
          final g = named.group(1)!.trim();
          if (!RegExp(r'^(oluştur|olustur|ekle|yeni)$', caseSensitive: false)
              .hasMatch(g)) {
            name = g;
          }
        }
      }
      name = name.isEmpty
          ? ((snapshot['masalar'] as Map?)?['onerilenSonrakiMasaAdi']
                  as String? ??
              '')
          : name;
      return [OrdiToolCall('create_table', {'name': name})];
    }
    return const [];
  }

  static bool _isDelete(String lower) =>
      lower.contains('sil') ||
      lower.contains('kaldır') ||
      lower.contains('kaldir') ||
      lower.contains('iptal et');

  static bool _looksLikeCreateTable(String lower) {
    final create = lower.contains('oluştur') ||
        lower.contains('olustur') ||
        lower.contains('ekle');
    return create && lower.contains('masa') && !lower.contains('açık masa');
  }

  static OrdiToolCall? _parseAddItem(String q) {
    final lower = q.toLowerCase();
    if (!(lower.contains('ekle') ||
        lower.contains('menü') ||
        lower.contains('menu'))) {
      return null;
    }
    final priced = RegExp(
      r'(.+?)\s+alt[iı]na\s+(.+?)\s+(\d+(?:[.,]\d+)?)\s*(?:tl|₺)?',
      caseSensitive: false,
    ).firstMatch(q);
    if (priced != null) {
      return OrdiToolCall('add_menu_item', {
        'category': priced.group(1)!.trim(),
        'name': priced.group(2)!.trim(),
        'price': priced.group(3),
      });
    }
    return null;
  }
}

bool ordiIsAffirmative(String q) {
  final n = q.trim().toLowerCase();
  return const {
    'evet',
    'evet.',
    'onay',
    'onayla',
    'onaylıyorum',
    'onayliyorum',
    'tamam',
    'olur',
    'yap',
    'yes',
    'ok',
  }.contains(n);
}

bool ordiIsNegative(String q) {
  final n = q.trim().toLowerCase();
  return const {
    'hayır',
    'hayir',
    'hayır.',
    'iptal',
    'vazgeç',
    'vazgec',
    'no',
    'olmaz',
  }.contains(n);
}
