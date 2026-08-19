import 'package:get/get.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/table_service.dart';

/// Turkish number formatting (1.234,56) without pulling a locale-aware
/// formatter into a hot path. Used both for the JSON snapshot's human-readable
/// strings and for [OrdiLocalBrain]'s offline answers.
String ordiMoney(num value, {String symbol = '₺'}) =>
    '$symbol${ordiNumber(value, decimals: 2)}';

String ordiNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final dotIndex = fixed.indexOf('.');
  final intPart = dotIndex == -1 ? fixed : fixed.substring(0, dotIndex);
  final decPart = dotIndex == -1 ? '' : fixed.substring(dotIndex + 1);

  final negative = intPart.startsWith('-');
  final digits = negative ? intPart.substring(1) : intPart;

  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }

  final head = '${negative ? '-' : ''}$grouped';
  return decPart.isEmpty ? head : '$head,$decPart';
}

const _weekdaysTr = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const _monthsTr = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _pad(int n) => n.toString().padLeft(2, '0');

/// Builds the compact business snapshot that travels with every question.
///
/// Design: the app already keeps every table, sale, menu and stock row in
/// memory (all services are realtime-backed `GetxService`s), so the snapshot is
/// a pure local aggregation — no extra network round-trip and no risk of the
/// model inventing a number, because the arithmetic happens here rather than in
/// the LLM. Only aggregates and small samples are sent; raw sale rows are not.
class OrdiSnapshot {
  /// Hard caps keep the payload well under the edge function's 60k char limit
  /// even for a large venue.
  static const _maxTableRows = 40;
  static const _maxMenuItems = 150;
  static const _maxStockRows = 25;

  static Map<String, dynamic> build() {
    final now = DateTime.now();
    final currency = _has<SettingsService>()
        ? SettingsService.to.currencySymbol.value
        : '₺';

    return {
      'isletme': {
        'ad': _has<SettingsService>()
            ? (SettingsService.to.companyName.value.isEmpty
                ? 'İsimsiz işletme'
                : SettingsService.to.companyName.value)
            : 'İsimsiz işletme',
        'paraBirimi': currency,
        'kullanici': _has<AuthController>()
            ? (AuthController.to.user.value?.email ?? '')
            : '',
      },
      'simdi': {
        'tarih': '${now.year}-${_pad(now.month)}-${_pad(now.day)}',
        'saat': '${_pad(now.hour)}:${_pad(now.minute)}',
        'gunAdi': _weekdaysTr[now.weekday - 1],
        'ayAdi': _monthsTr[now.month - 1],
      },
      'satis': _sales(now),
      'masalar': _tables(),
      'stok': _stock(),
      'menu': _menu(),
      'personel': _staff(now),
      'gunDurumu': _dayStatus(),
    };
  }

  static bool _has<T>() => Get.isRegistered<T>();

  // ── Sales ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _sales(DateTime now) {
    if (!_has<SalesHistoryService>()) return {'veriYok': true};
    final svc = SalesHistoryService.to;
    final all = svc.sales.toList();
    if (all.isEmpty) {
      return {'kayitVar': false, 'not': 'Henüz hiç satış kaydı yok.'};
    }

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final prevMonth = DateTime(now.year, now.month - 1);

    // Bucket once instead of re-scanning the list per period.
    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    for (final sale in all) {
      final d = DateTime.tryParse(sale['date'] as String? ?? '');
      if (d == null) continue;
      byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(sale);
    }

    List<Map<String, dynamic>> range(DateTime from, [DateTime? toExclusive]) {
      final out = <Map<String, dynamic>>[];
      byDay.forEach((day, sales) {
        if (day.isBefore(from)) return;
        if (toExclusive != null && !day.isBefore(toExclusive)) return;
        out.addAll(sales);
      });
      return out;
    }

    final todaySales = byDay[today] ?? const [];

    return {
      'kayitVar': true,
      'bugun': {
        ..._period(todaySales),
        'saatlikCiro': {
          for (final e in _hourly(todaySales).entries)
            '${_pad(e.key)}:00': _round(e.value),
        },
      },
      'dun': _period(byDay[yesterday] ?? const []),
      'buHafta': _period(range(weekStart)),
      'buAy': _period(range(monthStart)),
      'gecenAy': _period(range(prevMonth, monthStart)),
      'son7Gun': {
        for (var i = 6; i >= 0; i--)
          _label(today.subtract(Duration(days: i))):
              _round(_total(byDay[today.subtract(Duration(days: i))] ?? const [])),
      },
      'tumZamanlar': {
        'ciro': _round(_total(all)),
        'adisyonSayisi': all.length,
        'ortalamaAdisyon': _round(_total(all) / all.length),
        'ilkSatisTarihi':
            _dayKey(byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b)),
        'not': 'Bu periyot için ürün ve ödeme kırılımı gönderilmiyor.',
      },
    };
  }

  static String _label(DateTime d) =>
      '${_dayKey(d)} ${_weekdaysTr[d.weekday - 1]}';

  static String _dayKey(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  static double _total(List<Map<String, dynamic>> sales) =>
      sales.fold(0.0, (sum, s) => sum + _num(s['total']));

  static Map<String, dynamic> _period(List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return {'ciro': 0, 'adisyonSayisi': 0, 'ortalamaAdisyon': 0};
    }

    final ciro = _total(sales);
    final indirim = sales.fold(0.0, (sum, s) => sum + _num(s['discount']));

    final payments = <String, double>{};
    final itemQty = <String, int>{};
    final itemRevenue = <String, double>{};

    for (final sale in sales) {
      final method = (sale['paymentMethod'] as String?) ?? 'cash';
      payments[method] = (payments[method] ?? 0) + _num(sale['total']);

      for (final raw in (sale['items'] as List? ?? const [])) {
        final item = raw as Map;
        final name = item['name'] as String? ?? '?';
        final qty = _num(item['quantity']).round();
        itemQty[name] = (itemQty[name] ?? 0) + qty;
        itemRevenue[name] =
            (itemRevenue[name] ?? 0) + _num(item['price']) * qty;
      }
    }

    final topByQty = itemQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'ciro': _round(ciro),
      'adisyonSayisi': sales.length,
      'ortalamaAdisyon': _round(ciro / sales.length),
      'toplamIndirim': _round(indirim),
      'odemeYontemleri': {
        for (final e in payments.entries) _paymentLabel(e.key): _round(e.value),
      },
      'satilanUrunAdedi': itemQty.values.fold(0, (a, b) => a + b),
      'enCokSatan': [
        for (final e in topByQty.take(8))
          {
            'urun': e.key,
            'adet': e.value,
            'ciro': _round(itemRevenue[e.key] ?? 0),
          },
      ],
    };
  }

  static Map<int, double> _hourly(List<Map<String, dynamic>> sales) {
    final out = <int, double>{};
    for (final sale in sales) {
      final d = DateTime.tryParse(sale['date'] as String? ?? '');
      if (d == null) continue;
      out[d.hour] = (out[d.hour] ?? 0) + _num(sale['total']);
    }
    return Map.fromEntries(
      out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  static String _paymentLabel(String key) => switch (key) {
        'cash' => 'nakit',
        'card' || 'credit' || 'creditCard' => 'kart',
        _ => key,
      };

  // ── Tables ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _tables() {
    if (!_has<TableService>()) return {'veriYok': true};
    final tables = TableService.to.tables.toList();
    final occupied = tables.where((t) => t['isOccupied'] == true).toList();

    final open = occupied.fold<double>(
      0,
      (sum, t) => sum + (_num(t['total']) - _num(t['discount'])),
    );

    return {
      'toplamMasa': tables.length,
      'doluMasa': occupied.length,
      'bosMasa': tables.length - occupied.length,
      'acikAdisyonToplami': _round(open),
      'doluMasaDetay': [
        for (final t in occupied.take(_maxTableRows))
          {
            'masa': t['name'],
            'tutar': _round(_num(t['total']) - _num(t['discount'])),
            'urunCesidi': (t['orders'] as List? ?? const []).length,
            'urunAdedi': (t['orders'] as List? ?? const []).fold<int>(
              0,
              (sum, o) => sum + _num((o as Map)['quantity']).round(),
            ),
            'garson': (t['staffEmail'] as String?)?.isEmpty ?? true
                ? null
                : t['staffEmail'],
          },
      ],
      if (occupied.length > _maxTableRows)
        'not': 'Sadece ilk $_maxTableRows dolu masa listelendi.',
    };
  }

  // ── Stock ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _stock() {
    if (!_has<InventoryService>()) return {'veriYok': true};
    final svc = InventoryService.to;
    final tracked = svc.stock.entries.toList();
    if (tracked.isEmpty) {
      return {
        'takipEdilenUrun': 0,
        'not': 'Hiçbir ürün için stok takibi açılmamış.',
      };
    }

    final out = <String, int>{};
    final critical = <Map<String, dynamic>>[];
    for (final e in tracked) {
      out[e.key] = e.value;
    }

    final sorted = tracked..sort((a, b) => a.value.compareTo(b.value));
    for (final e in sorted.take(_maxStockRows)) {
      if (e.value > InventoryService.lowStockThreshold) break;
      critical.add({
        'urun': e.key,
        'kalanAdet': e.value,
        'durum': e.value <= 0 ? 'tükendi' : 'kritik',
      });
    }

    return {
      'takipEdilenUrun': tracked.length,
      'kritikEsik': InventoryService.lowStockThreshold,
      'tukenenUrunSayisi': out.values.where((v) => v <= 0).length,
      'kritikUrunSayisi': out.values
          .where((v) => v > 0 && v <= InventoryService.lowStockThreshold)
          .length,
      'kritikVeTukenenler': critical,
    };
  }

  // ── Menu ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _menu() {
    if (!_has<MenuService>()) return {'veriYok': true};
    final menus = MenuService.to.menus.toList();

    var budget = _maxMenuItems;
    var totalItems = 0;
    final categories = <Map<String, dynamic>>[];

    for (final menu in menus) {
      final items = (menu['items'] as List? ?? const []);
      totalItems += items.length;
      final take = items.take(budget.clamp(0, items.length)).toList();
      budget -= take.length;
      categories.add({
        'kategori': menu['name'],
        'urunSayisi': items.length,
        'urunler': [
          for (final raw in take)
            {
              'ad': (raw as Map)['name'],
              'fiyat': _round(_num(raw['price'])),
            },
        ],
      });
    }

    final prices = [
      for (final m in menus)
        for (final i in (m['items'] as List? ?? const [])) _num((i as Map)['price']),
    ]..sort();

    return {
      'kategoriSayisi': menus.length,
      'toplamUrun': totalItems,
      if (prices.isNotEmpty) 'enDusukFiyat': _round(prices.first),
      if (prices.isNotEmpty) 'enYuksekFiyat': _round(prices.last),
      if (prices.isNotEmpty)
        'ortalamaFiyat':
            _round(prices.fold<double>(0, (a, b) => a + b) / prices.length),
      'kategoriler': categories,
      if (totalItems > _maxMenuItems)
        'not': 'Ürün listesi $_maxMenuItems ürüne kısaltıldı.',
    };
  }

  // ── Staff & shifts ─────────────────────────────────────────────────────

  static Map<String, dynamic> _staff(DateTime now) {
    final result = <String, dynamic>{};

    if (_has<StaffService>()) {
      final staff = StaffService.to.staffList.toList();
      result['kayitliPersonel'] = staff.length;
      // PINs are deliberately excluded — Ordi never needs them and they must
      // not leave the device.
      result['isimler'] = [for (final s in staff) s['name']];
      result['ekrandaAktif'] = StaffService.to.currentStaffIdentifier.isEmpty
          ? null
          : StaffService.to.currentStaffIdentifier;
    }

    if (_has<ShiftService>()) {
      final svc = ShiftService.to;
      final todays = svc.getShiftsForDate(now);
      result['bugunVardiya'] = [
        for (final shift in todays)
          {
            'kisi': shift['staffEmail'],
            'giris': _clock(shift['startTime'] as String?),
            'cikis': _clock(shift['endTime'] as String?),
            'devamEdiyor': shift['endTime'] == null,
            'calismaDakika': svc.getWorkMinutes(shift),
            'molaDakika': svc.getBreakMinutes(shift),
          },
      ];
      result['suAndaCalisan'] =
          todays.where((s) => s['endTime'] == null).length;
    }

    return result;
  }

  static String? _clock(String? iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso);
    return d == null ? null : '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  // ── Day status ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _dayStatus() {
    if (!_has<DayService>()) return {'veriYok': true};
    final active = DayService.to.activeDays.toList();
    return {
      'acikGunSayisi': active.length,
      'gunuAcanlar': [for (final d in active) d['started_by']],
      'toplamKayitliGun': DayService.to.allDays.length,
    };
  }

  // ── Primitives ─────────────────────────────────────────────────────────

  static double _num(Object? v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  /// Two decimals is plenty for money and keeps the JSON small.
  static num _round(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.round() : r;
  }
}
