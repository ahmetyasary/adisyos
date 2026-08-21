import 'package:get/get.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/section_service.dart';
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
      'mutfak': _kitchen(),
      'stok': _stock(),
      'menu': _menu(),
      'personel': _staff(now),
      'gunDurumu': _dayStatus(),
      'uygulamaKilavuzu': _appGuide(),
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
      'sonIslemler': [
        for (final s in all.take(8))
          {
            'masa': s['tableName'],
            'tutar': _round(_num(s['total'])),
            'odeme': _paymentLabel((s['paymentMethod'] as String?) ?? 'cash'),
            'saat': _clock(s['date'] as String?),
            'tarih': _dayKey(
              DateTime.tryParse(s['date'] as String? ?? '') ?? DateTime.now(),
            ),
          },
      ],
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

  static String _paymentLabel(String key) {
    if (Get.isRegistered<SettingsService>()) {
      return SettingsService.to.paymentMethodLabel(key);
    }
    return switch (key) {
      'cash' => 'nakit',
      'card' || 'credit' || 'creditCard' => 'kart',
      'transfer' => 'havale',
      _ => key,
    };
  }

  // ── Tables ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _tables() {
    if (!_has<TableService>()) return {'veriYok': true};
    final tables = TableService.to.tables.toList();
    final occupied = tables.where((t) => t['isOccupied'] == true).toList();
    final openSince = _tableOpenSince();

    final open = occupied.fold<double>(
      0,
      (sum, t) => sum + (_num(t['total']) - _num(t['discount'])),
    );

    return {
      'toplamMasa': tables.length,
      'doluMasa': occupied.length,
      'bosMasa': tables.length - occupied.length,
      'acikAdisyonToplami': _round(open),
      'masaAdlari': [for (final t in tables) t['name']],
      'onerilenSonrakiMasaAdi': _nextTableName(tables),
      'bolumler': _sectionNames(),
      'not':
          '"açık hesap / açık adisyon" = henüz ödenmemiş masa. '
          '"kaç gündür açık" için masanın acikSureMetin alanına bak; '
          'gunDurumu.acikGunSayisi gün süresi değildir.',
      'doluMasaDetay': [
        for (final t in occupied.take(_maxTableRows))
          _occupiedDetail(t, openSince),
      ],
      if (occupied.length > _maxTableRows)
        'kisaltma': 'Sadece ilk $_maxTableRows dolu masa listelendi.',
    };
  }

  static Map<String, dynamic> _occupiedDetail(
    Map<String, dynamic> t,
    Map<String, DateTime> openSince,
  ) {
    final orders = (t['orders'] as List? ?? const []);
    final name = t['name'] as String? ?? '';
    final id = t['id'];
    final since = openSince['id:$id'] ?? openSince['name:$name'];
    final elapsed = since == null ? null : DateTime.now().difference(since);

    return {
      'masa': name,
      'tutar': _round(_num(t['total']) - _num(t['discount'])),
      'indirim': _round(_num(t['discount'])),
      'urunCesidi': orders.length,
      'urunAdedi': orders.fold<int>(
        0,
        (sum, o) => sum + _num((o as Map)['quantity']).round(),
      ),
      'urunler': [
        for (final raw in orders.take(20))
          {
            'ad': (raw as Map)['name'],
            'adet': _num(raw['quantity']).round(),
            'birimFiyat': _round(_num(raw['price'])),
          },
      ],
      'garson': (t['staffEmail'] as String?)?.isEmpty ?? true
          ? null
          : t['staffEmail'],
      if (since != null) 'ilkSiparis': _dateTimeLabel(since),
      if (elapsed != null) 'acikSureDakika': elapsed.inMinutes,
      if (elapsed != null) 'acikSureMetin': _formatElapsed(elapsed),
    };
  }

  static List<String> _sectionNames() {
    if (!_has<SectionService>()) return const [];
    return [
      for (final s in SectionService.to.sections) s['name'] as String,
    ];
  }

  static String _nextTableName(List<Map<String, dynamic>> tables) {
    var maxN = 0;
    for (final t in tables) {
      final name = (t['name'] as String? ?? '').trim();
      final m = RegExp(r'^masa\s*(\d+)$', caseSensitive: false).firstMatch(name);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    if (maxN > 0) return 'Masa ${maxN + 1}';
    return 'Masa ${tables.length + 1}';
  }

  /// Earliest kitchen ticket per table is the best proxy for "when did this
  /// tab open" — tables themselves have no occupied_at column.
  static Map<String, DateTime> _tableOpenSince() {
    final out = <String, DateTime>{};
    if (!_has<KitchenService>()) return out;
    for (final ticket in KitchenService.to.tickets) {
      final at = DateTime.tryParse(ticket['orderedAt'] as String? ?? '');
      if (at == null) continue;
      final id = ticket['tableId'];
      final name = ticket['tableName'] as String? ?? '';
      void consider(String key) {
        final prev = out[key];
        if (prev == null || at.isBefore(prev)) out[key] = at;
      }

      if (id != null) consider('id:$id');
      if (name.isNotEmpty) consider('name:$name');
    }
    return out;
  }

  static Map<String, dynamic> _kitchen() {
    if (!_has<KitchenService>()) return {'veriYok': true};
    final tickets = KitchenService.to.tickets.toList();
    final pending = tickets.where((t) => t['status'] != 'ready').length;
    return {
      'biletSayisi': tickets.length,
      'bekleyen': pending,
      'hazir': tickets.length - pending,
      'sonBiletler': [
        for (final t in tickets.take(15))
          {
            'masa': t['tableName'],
            'urun': t['itemName'],
            'adet': t['quantity'],
            'durum': t['status'],
            'saat': _clock(t['orderedAt'] as String?),
          },
      ],
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

  static Map<String, dynamic> _dayStatus() {
    if (!_has<DayService>()) return {'veriYok': true};
    final active = DayService.to.activeDays.toList();
    return {
      'acikGunKaydi': active.length,
      'acikGunSayisiAnlami':
          'Şu anda günü kapatmamış kaç oturum var. Süre değildir.',
      'aktifGunler': [
        for (final d in active) _activeDay(d),
      ],
      'toplamKayitliGun': DayService.to.allDays.length,
    };
  }

  static Map<String, dynamic> _activeDay(Map<String, dynamic> d) {
    final started = _parseLocal(d['started_at'] as String?);
    final elapsed =
        started == null ? Duration.zero : DateTime.now().difference(started);
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    return {
      'acan': d['started_by'],
      'baslangic': started == null ? null : _dateTimeLabel(started),
      'gunTarihi': d['day_date'],
      'sureDakika': safe.inMinutes,
      'sureMetin': _formatElapsed(safe),
      'sureGun': (safe.inHours / 24).floor(),
    };
  }

  static Map<String, dynamic> _appGuide() => {
        'ad': 'Orderix',
        'asistan': 'Ordi',
        'roller': {
          'admin': 'Tüm ekranlar ve Ordi.',
          'personel': 'PIN ile giriş; masalar ve sipariş. Ordi görünmez.',
        },
        'ekranlar': {
          'Ana Ekran':
              'Gün özeti, ciro kartları, grafik, son işlemler. Günü başlat/bitir.',
          'Masalar':
              'Masa ekle, sipariş yaz, adisyonu gör, nakit/kart ödeme, kısmi ödeme, indirim, masalar arası taşıma.',
          'Mutfak': 'Sipariş biletleri; hazır olunca işaretlenir.',
          'Menüler': 'Kategori ve ürün, fiyat, görsel.',
          'Stoklar':
              'Ürün stoğu. 5 ve altı kritik, 0 tükenen. Sipariş stok düşer.',
          'Günler': 'Geçmiş gün açılış/kapanış kayıtları.',
          'Raporlar': 'Tarihe göre ciro, ödeme tipi, en çok satanlar.',
          'Personel': 'Personel ekle, PIN, vardiya.',
          'Bildirimler': 'Satış ve sistem bildirimleri.',
          'Ayarlar': 'İşletme adı, para birimi, hesap silme.',
        },
        'nasil': {
          'gunuBaslat': 'Ana Ekran veya Masalar üstündeki Güne Başla.',
          'gunuBitir':
              'Günü Bitir. Açık masa varken bitmez; önce masaları kapatın.',
          'siparisYaz': 'Masalar → masa → menüden ürün ekle. Ordi de ekleyebilir.',
          'masaOlustur':
              'Masalar → Masa Ekle, veya Ordi’ye “Masa 15 oluştur” deyin.',
          'urunEkle':
              'Menüler ekranı, veya Ordi’ye “İçecekler altına Ayran 25 TL ekle” deyin.',
          'odemeAl':
              'Açık masa → ödeme, veya Ordi’ye söyleyin (onay ister). Nakit/kart. Kısmi ödeme ürün bazlı.',
          'masaTasi':
              'Açık masada siparişi başka masaya taşıyın, veya Ordi’ye söyleyin (onay ister).',
          'indirim':
              'Açık adisyonda yüzde indirim, veya Ordi (onay ister).',
          'stok':
              'Stoklar ekranı veya Ordi. Yeni takip hemen açılır; mevcut stok değişince onay ister.',
          'ordiYazma':
              'Ekleme onay sormaz. Değişiklik evet/hayır ister. Silme (masa, ürün, sipariş iptali, personel) asla yapılmaz.',
        },
        'terimler': {
          'acikHesap': 'Ödenmemiş masa adisyonu.',
          'acikGun':
              'Günü Bitir yapılmamış çalışma oturumu. Süre: aktifGunler.sureMetin.',
          'adisyon': 'Kapanmış satış kaydı (raporlara düşer).',
        },
      };

  static String? _clock(String? iso) {
    if (iso == null) return null;
    final d = _parseLocal(iso);
    return d == null ? null : '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  static String _dateTimeLabel(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  /// Matches DayToggleCard: timestamptz comes back as UTC but was written as
  /// local wall-clock, so rebuild from components when tagged UTC.
  static DateTime? _parseLocal(String? iso) {
    var st = DateTime.tryParse(iso ?? '');
    if (st == null) return null;
    if (st.isUtc) {
      st = DateTime(st.year, st.month, st.day, st.hour, st.minute, st.second);
    }
    return st;
  }

  static String _formatElapsed(Duration e) {
    final d = e.inDays;
    final h = e.inHours % 24;
    final m = e.inMinutes % 60;
    if (d > 0) return '$d gün ${h}sa ${m}dk';
    if (e.inHours > 0) return '${e.inHours}sa ${m}dk';
    return '${e.inMinutes}dk';
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
