import 'package:orderix/features/ordi/data/ordi_snapshot.dart';

/// Offline, deterministic answers for the most common questions.
///
/// This is the fallback path: when the `ordi` edge function is unreachable, the
/// device is offline, or the daily Gemini quota is spent, the assistant still
/// answers instead of showing an error. It reads the exact same snapshot the
/// remote brain gets, so the numbers always agree.
///
/// It intentionally does no fuzzy language understanding — it keys off Turkish
/// stems and returns [null] when it isn't confident, so the caller can show an
/// honest "I can't answer this offline" message rather than a wrong one.
class OrdiLocalBrain {
  const OrdiLocalBrain(this.snapshot);

  final Map<String, dynamic> snapshot;

  String get _currency =>
      (snapshot['isletme'] as Map?)?['paraBirimi'] as String? ?? '₺';

  /// Returns an answer, or null if no rule matched confidently.
  String? answer(String question) {
    final q = _normalise(question);
    if (q.isEmpty) return null;

    final period = _period(q);

    if (_any(q, ['kac gun', 'ne kadar sure', 'ne zamandir', 'kac saattir']) &&
        _any(q, ['acik', 'gun', 'hesap', 'adisyon', 'masa'])) {
      return _openDuration(q);
    }
    if (_any(q, ['nasil', 'nereden', 'hangi ekran', 'nerede', 'kilavuz']) &&
        !_any(q, ['gidiyor', 'gidisat'])) {
      return _howTo(q);
    }
    if (_any(q, ['ciro', 'kazanc', 'hasilat', 'satis', 'gelir', 'para kazan'])) {
      return _revenue(period);
    }
    if (_any(q, ['en cok satan', 'populer', 'cok satilan', 'hangi urun'])) {
      return _topItems(period);
    }
    if (_any(q, ['ortalama adisyon', 'ortalama sepet', 'adisyon ortalama'])) {
      return _averageTicket(period);
    }
    if (_any(q, ['masa', 'adisyon', 'acik hesap', 'dolu'])) {
      return _tables();
    }
    if (_any(q, ['stok', 'tukendi', 'tukenen', 'kritik', 'azalan', 'depo'])) {
      return _stock();
    }
    if (_any(q, ['nakit', 'kart', 'odeme'])) {
      return _payments(period);
    }
    if (_any(q, ['personel', 'garson', 'vardiya', 'calisan', 'mesai'])) {
      return _staff();
    }
    if (_any(q, ['menu', 'fiyat', 'urun sayisi', 'kategori'])) {
      return _menu();
    }
    if (_any(q, ['ozet', 'durum', 'nasil gidiyor', 'genel'])) {
      return summary();
    }
    return null;
  }

  /// The "how are we doing" briefing. Also used as the first-run greeting.
  String summary() {
    final today = _periodData('bugun');
    final lines = <String>[];

    if (today != null) {
      lines.add(
        '• Bugün ${_money(today['ciro'])} ciro, '
        '${today['adisyonSayisi']} adisyon.',
      );
      final yesterday = _periodData('dun');
      final delta = _delta(today['ciro'], yesterday?['ciro']);
      if (delta != null) lines.add('• Düne göre $delta.');
    }

    final tables = snapshot['masalar'] as Map?;
    if (tables != null && tables['doluMasa'] != null) {
      lines.add(
        '• ${tables['doluMasa']}/${tables['toplamMasa']} masa dolu, '
        'açık adisyon toplamı ${_money(tables['acikAdisyonToplami'])}.',
      );
    }

    final stock = snapshot['stok'] as Map?;
    final criticalCount =
        ((stock?['kritikUrunSayisi'] ?? 0) as num).toInt() +
            ((stock?['tukenenUrunSayisi'] ?? 0) as num).toInt();
    if (criticalCount > 0) {
      lines.add('• $criticalCount ürünün stoğu kritik seviyede.');
    }

    if (lines.isEmpty) return 'Henüz özet çıkaracak kadar veri yok.';
    return 'İşte günün durumu:\n${lines.join('\n')}';
  }

  // ── Rules ──────────────────────────────────────────────────────────────

  String _revenue(String period) {
    final data = _periodData(period);
    if (data == null) return 'Henüz satış kaydı bulunmuyor.';

    final label = _periodLabel(period);
    if ((data['adisyonSayisi'] as num?) == 0) {
      return '$label henüz satış yok.';
    }

    final parts = <String>[
      '$label ciro **${_money(data['ciro'])}**, '
          '${data['adisyonSayisi']} adisyon '
          '(ortalama ${_money(data['ortalamaAdisyon'])}).',
    ];

    if (period == 'bugun') {
      final delta = _delta(data['ciro'], _periodData('dun')?['ciro']);
      if (delta != null) parts.add('Düne göre $delta.');
    }
    if (period == 'buAy') {
      final delta = _delta(data['ciro'], _periodData('gecenAy')?['ciro']);
      if (delta != null) parts.add('Geçen ayın tamamına göre $delta.');
    }
    return parts.join(' ');
  }

  String _topItems(String rawPeriod) {
    final period = _breakdownPeriod(rawPeriod);
    final data = _periodData(period);
    final top = (data?['enCokSatan'] as List?) ?? const [];
    if (top.isEmpty) return '${_periodLabel(period)} satılan ürün yok.';

    final lines = [
      for (final raw in top.take(5))
        '• ${(raw as Map)['urun']} — ${raw['adet']} adet, '
            '${_money(raw['ciro'])}',
    ];
    return '${_redirectNote(rawPeriod, period)}'
        '${_periodLabel(period)} en çok satanlar:\n${lines.join('\n')}';
  }

  String _averageTicket(String period) {
    final data = _periodData(period);
    if (data == null || (data['adisyonSayisi'] as num?) == 0) {
      return '${_periodLabel(period)} adisyon kapanmadığı için ortalama hesaplanamıyor.';
    }
    return '${_periodLabel(period)} ortalama adisyon tutarı '
        '**${_money(data['ortalamaAdisyon'])}** '
        '(${data['adisyonSayisi']} adisyon, toplam ${_money(data['ciro'])}).';
  }

  String _tables() {
    final t = snapshot['masalar'] as Map?;
    if (t == null || t['toplamMasa'] == null) {
      return 'Masa bilgisine şu an erişemiyorum.';
    }
    if ((t['doluMasa'] as num) == 0) {
      return 'Şu anda ${t['toplamMasa']} masanın tamamı boş, açık adisyon yok.';
    }

    final detail = (t['doluMasaDetay'] as List?) ?? const [];
    final lines = [
      for (final raw in detail.take(8))
        '• ${(raw as Map)['masa']} — ${_money(raw['tutar'])}'
            '${raw['garson'] == null ? '' : ' (${raw['garson']})'}',
    ];

    return '${t['doluMasa']}/${t['toplamMasa']} masa dolu. '
        'Açık adisyon toplamı **${_money(t['acikAdisyonToplami'])}**.'
        '${lines.isEmpty ? '' : '\n${lines.join('\n')}'}';
  }

  /// "Kaç gündür açık hesap" — prefer the occupied table duration, also
  /// report the active business-day elapsed time so the two aren't confused.
  String _openDuration(String q) {
    final days = snapshot['gunDurumu'] as Map?;
    final active = (days?['aktifGunler'] as List?) ?? const [];
    final tables = snapshot['masalar'] as Map?;
    final occupied = (tables?['doluMasaDetay'] as List?) ?? const [];

    final lines = <String>[];
    if (active.isNotEmpty) {
      final g = active.first as Map;
      lines.add(
        'Aktif çalışma günü **${g['sureMetin']}** süredir açık '
        '(${g['acan']}, başlangıç ${g['baslangic']}).',
      );
    } else {
      lines.add('Şu anda açık çalışma günü yok.');
    }

    if (occupied.isEmpty) {
      lines.add('Açık masa adisyonu yok.');
    } else {
      for (final raw in occupied.take(8)) {
        final t = raw as Map;
        final sure = t['acikSureMetin'] as String?;
        lines.add(
          '• ${t['masa']}: ${_money(t['tutar'])}'
          '${sure == null ? ' (ilk sipariş saati yok)' : ', ${sure}dir açık'}',
        );
      }
    }
    return lines.join('\n');
  }

  String _howTo(String q) {
    final g = snapshot['uygulamaKilavuzu'] as Map?;
    final how = g?['nasil'] as Map? ?? {};
    if (_any(q, ['gunu bitir', 'gun kapat', 'gun sonu'])) {
      return how['gunuBitir'] as String? ??
          'Ana Ekran’dan Günü Bitir. Açık masa varsa önce kapatın.';
    }
    if (_any(q, ['odeme', 'hesap kapat', 'adisyon kapat'])) {
      return how['odemeAl'] as String? ??
          'Masalar → açık masa → ödeme.';
    }
    if (_any(q, ['siparis'])) {
      return how['siparisYaz'] as String? ??
          'Masalar → masa seç → menüden ürün ekle.';
    }
    final screens = g?['ekranlar'] as Map? ?? {};
    if (screens.isEmpty) {
      return 'Sol menüden Ana Ekran, Masalar, Mutfak, Menüler, Stoklar, Günler, Raporlar ve Personel’e geçebilirsiniz.';
    }
    final lines = [
      for (final e in screens.entries.take(10)) '• ${e.key}: ${e.value}',
    ];
    return 'Orderix ekranları:\n${lines.join('\n')}';
  }

  String _stock() {
    final s = snapshot['stok'] as Map?;
    if (s == null || (s['takipEdilenUrun'] as num?) == 0) {
      return 'Hiçbir ürün için stok takibi açılmamış. '
          'Menü ekranından ürünlere stok tanımlayabilirsiniz.';
    }

    final critical = (s['kritikVeTukenenler'] as List?) ?? const [];
    if (critical.isEmpty) {
      return '${s['takipEdilenUrun']} üründe stok takibi açık ve '
          'hiçbiri kritik seviyede değil.';
    }

    final lines = [
      for (final raw in critical.take(10))
        '• ${(raw as Map)['urun']} — ${raw['kalanAdet']} adet '
            '(${raw['durum']})',
    ];
    return 'Dikkat edilmesi gereken ${critical.length} ürün var:\n'
        '${lines.join('\n')}';
  }

  String _payments(String rawPeriod) {
    final period = _breakdownPeriod(rawPeriod);
    final data = _periodData(period);
    final methods = (data?['odemeYontemleri'] as Map?) ?? const {};
    if (methods.isEmpty) {
      return '${_periodLabel(period)} ödeme kaydı yok.';
    }
    final total = methods.values.fold<double>(
      0,
      (sum, v) => sum + ((v as num?)?.toDouble() ?? 0),
    );
    final lines = [
      for (final e in methods.entries)
        '• ${e.key}: ${_money(e.value)}'
            '${total == 0 ? '' : ' (%${(((e.value as num).toDouble() / total) * 100).round()})'}',
    ];
    return '${_redirectNote(rawPeriod, period)}'
        '${_periodLabel(period)} ödeme dağılımı:\n${lines.join('\n')}';
  }

  String _staff() {
    final p = snapshot['personel'] as Map?;
    if (p == null || p.isEmpty) return 'Personel bilgisine erişemiyorum.';

    final shifts = (p['bugunVardiya'] as List?) ?? const [];
    final header = '${p['kayitliPersonel'] ?? 0} kayıtlı personel var, '
        'şu anda ${p['suAndaCalisan'] ?? 0} kişi vardiyada.';
    if (shifts.isEmpty) return '$header Bugün açılmış vardiya yok.';

    final lines = [
      for (final raw in shifts.take(10))
        '• ${(raw as Map)['kisi']} — ${raw['giris'] ?? '?'}'
            '${raw['devamEdiyor'] == true ? ' (devam ediyor)' : ' - ${raw['cikis']}'}'
            ', ${_hours(raw['calismaDakika'])} çalışma',
    ];
    return '$header\n${lines.join('\n')}';
  }

  String _menu() {
    final m = snapshot['menu'] as Map?;
    if (m == null || m['toplamUrun'] == null) {
      return 'Menü bilgisine erişemiyorum.';
    }
    return 'Menüde ${m['kategoriSayisi']} kategori ve '
        '${m['toplamUrun']} ürün var. '
        'Fiyatlar ${_money(m['enDusukFiyat'])} ile '
        '${_money(m['enYuksekFiyat'])} arasında, '
        'ortalama ${_money(m['ortalamaFiyat'])}.';
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Map<String, dynamic>? _periodData(String key) {
    final sales = snapshot['satis'] as Map?;
    if (sales == null || sales['kayitVar'] != true) return null;
    final data = sales[key];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// Maps question wording to a snapshot period key. Defaults to today.
  String _period(String q) {
    if (_any(q, ['dun'])) return 'dun';
    if (_any(q, ['gecen ay', 'onceki ay'])) return 'gecenAy';
    if (_any(q, ['bu ay', 'aylik', 'ayin'])) return 'buAy';
    if (_any(q, ['hafta'])) return 'buHafta';
    if (_any(q, ['tum zaman', 'toplam', 'butun', 'simdiye kadar'])) {
      return 'tumZamanlar';
    }
    return 'bugun';
  }

  /// The snapshot only carries per-product and per-payment breakdowns for
  /// bounded periods; "all time" would blow up the payload. Questions that need
  /// a breakdown are answered for the current month instead.
  String _breakdownPeriod(String period) =>
      period == 'tumZamanlar' ? 'buAy' : period;

  String _redirectNote(String requested, String used) => requested == used
      ? ''
      : 'Tüm zamanların ürün kırılımını tutmuyorum, bu ayı gösteriyorum.\n';

  String _periodLabel(String key) => switch (key) {
        'dun' => 'Dün',
        'buHafta' => 'Bu hafta',
        'buAy' => 'Bu ay',
        'gecenAy' => 'Geçen ay',
        'tumZamanlar' => 'Tüm zamanlarda',
        _ => 'Bugün',
      };

  String _money(Object? value) =>
      ordiMoney(((value as num?) ?? 0).toDouble(), symbol: _currency);

  String _hours(Object? minutes) {
    final m = ((minutes as num?) ?? 0).toInt();
    if (m < 60) return '${m}dk';
    return '${m ~/ 60}sa ${m % 60}dk';
  }

  /// "%18 artış" / "%7 düşüş", or null when there's no meaningful baseline.
  String? _delta(Object? current, Object? previous) {
    final now = ((current as num?) ?? 0).toDouble();
    final before = ((previous as num?) ?? 0).toDouble();
    if (before <= 0) return null;
    final pct = ((now - before) / before) * 100;
    if (pct.abs() < 1) return 'neredeyse aynı';
    return '%${pct.abs().round()} ${pct > 0 ? 'artış' : 'düşüş'} var';
  }

  bool _any(String haystack, List<String> needles) =>
      needles.any(haystack.contains);

  /// Lowercases and strips Turkish diacritics so "ciro"/"cirö"/"CİRO" all hit
  /// the same rule.
  static String _normalise(String input) {
    const map = {
      'ı': 'i',
      'İ': 'i',
      'ş': 's',
      'Ş': 's',
      'ğ': 'g',
      'Ğ': 'g',
      'ü': 'u',
      'Ü': 'u',
      'ö': 'o',
      'Ö': 'o',
      'ç': 'c',
      'Ç': 'c',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    // Fold before lowercasing: Dart lowercases 'İ' to "i" + U+0307, which no
    // rule would ever match.
    final buffer = StringBuffer();
    for (final char in input.trim().split('')) {
      buffer.write(map[char] ?? char);
    }
    return buffer.toString().toLowerCase();
  }
}
