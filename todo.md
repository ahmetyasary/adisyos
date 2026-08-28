#Yapılacaklar

-ordi'ye iş ile ilgili tahmin özelliği ekle. forecast gelecekte neler olabilir?

-Cari hesaplar olsun (Müşteri için kayıt oluşsun. Ödemeleri oraya aktarılsın. Yada sen fikir ver?) ✅

-Dashboard ekranı güzelliştirilecek (widget mantığı olabilir.drag&drop) ✅ (Yetkili: uzun bas → sürükle, boyut S/M/L, ekle, sıfırla)

-pos entegrasyonu ✅ (Ayarlar > Entegrasyonlar > POS — ayar formu + kayıt; canlı API sonra)

-getir,trendyol,yemeksepeti entegrasyonu ✅ (Ayarlar > Entegrasyonlar > Pazaryeri — Getir / Trendyol Go / Yemeksepeti)

-dijital menü açık/koyu/sistem teması ✅

-koyu mod açık mod eklenecek. logolar görseller otomatik değişmeli. (sistem,açık,koyu) ✅

-Ayarlar en alta silik görünen 
    -smartlogy bilgisi eklenecek ✅
    -uygulama versiyonu eklenecek ✅

-web kısmından kayıt ol butonunu kaldır. ✅
-web favicon yap. ✅

-menü ekranında bir ürün silindiğinde silindikten sonra 5 sn içinde geri al butonuna basarsa listeye geri eklensin. geri sayım animasyonuda olsun. ✅

-masa sipariş detayında bir ürün silindiğinde silindikten sonra 6 sn içinde geri al butonuna basarsa listeye geri eklensin. geri sayım animasyonuda olsun. ✅

-titreşim hissini yükselt hatta ayarlara ekle kullanıcı düzenlesin. ✅ (Düşük/Orta/Yüksek, varsayılan Yüksek)
-bildirim sesini yükselt hatta ayaralara ekle kullanıcı düzenlesin. ✅ (ayrı anahtar + şiddet)

-raporlar kısmını detaylandır. (günlük, aylık, yıllık) ✅
  - günlük: özet + liste (tıkla ürünler) + ödeme/ürün/personel/masa
  - aylık: dönem kırılımları + gün gün özet → günlük
  - yıllık: özet kırılımlar + ay listesi → aylık
-raporlar günlük aylık yıllık rapor kısmında excel export alabilmeli ✅ (grafikli, çok sayfalı)

-masalar sayfasının üst kısmını düzenle. çok sıkışık. ✅ (üst alan kompakt, masa grid’ine daha fazla yer)

-personele rol tanımlaması eklenecek (Yetkili, Garson, Mutfak) ✅
  - mevcut personeller Garson; hesap admini Yetkili
  - Mutfak sadece mutfak menüsü; gün yoksa uyarı ekranı

-hızlı menü oluşturmayı düzenle. hızlı ürün eklendikten sonra direkt işlemi bitir. kullanıcı peş peşe ürün girmeyebilir. ✅

-ordi'ye sesli asistan yap ✅ (v1: basılı tut → STT → cevap TTS)

-masadan sipariş gelince bildirim gelmeli. uygulama sleep olup tekrar resume olunca bildirimler kontrol edilsin. ✅

-yazdırma önizlemesi✅

-dijital menü üzerinden sipariş + bekleyen siparişler + onay/masaya aktarım ✅ (canlı HTML: menu.orderix.tr index yükle)

-haptic olan her şeye ses ekle. ayarlardan kapatılabilsin. ✅

-adisyon yazıcı çıktı düzenleme olsun ✅

-Günü Bitir onaylandığında (hüzünlü) tık tık tıık şeklinden titreşim haptic olsun ✅
-Güne başlarken mutlu bir haptic olsun. ✅

-Yapay zeka ikonu üstlerde olunca kendi kendine konuşmaları alta gelsin. ✅
--ikonu yer değişikliği olunca titreşim. haptic olsun. ✅

-ödeme tamamlanınca kısa ve mutlu haptic(titreşim) olsun. genel olarak uygulama içi titreşimleri ayarlardan kapatabilsin ✅

-yapay zeka butonunu ayarlardan gizleme olsun. buton boyutunu 3 (küçük, orta,büyük)seçenekte seçebilsin ✅

-ödeme tipleri: nakit, kart, havale var. ama başka ödeme tipleride ekleyebilsin. örnek; yemek kartları ekleyebilsin ve bunlarıda raporlardada görelim. Ödeme tipleri ekleme menüsünü Ayarlar kısmında bir menü olsun. ✅

## IPA sonrası yapılan ana işlemler

- App Store yükleme hatası düzeltildi. `objective_c.framework` simulator mimarisi sorunu için `path_provider_foundation` sürümü sabitlendi ve temiz IPA alındı. ✅
- Giriş ekranı ve ödeme duvarının koyu mod kontrast sorunları düzeltildi. ✅
- Dijital menüye sistem/açık/koyu tema seçimi eklendi. ✅
- Dijital menü kategorileri sürükleyerek sıralanabilir ve kategoriler “Öne çıkan” olarak işaretlenebilir hale getirildi. Seçim, sıralama ve öne çıkan durumu otomatik kaydediliyor. ✅
- Tamamlanan ödemeler ekranı eklendi. Son 20 ödeme görüntülenebiliyor; ödeme tipi, ürün, adet ve fiyat düzenlenebiliyor, toplam otomatik hesaplanıyor. ✅
- Cari Hesaplar özelliği eklendi: Ayarlar anahtarı, menü görünürlüğü, müşteri oluşturma/seçme, masayı cariye aktarma, açık hesap badge’i, detay görüntüleme, ödeme tamamlama ve silme. ✅
- Cari hesap ödemeleri tamamlanan ödemeler ve raporlarda “Cari - Ödeme Tipi” olarak gösteriliyor. ✅
- “Cari’ye Gönder” işlemi masa aksiyonlarına taşındı ve işlem sırasında “Taşınıyor…” yüklenme durumu eklendi. ✅
- Mutfak kayıtlarında geçici masa/sipariş kimliği nedeniyle oluşan UUID hatası düzeltildi. ✅
- Cari Hesaplar ve dijital menü için Supabase tabloları, migration’lar ve canlı menü API güncellemeleri yapıldı. ✅
- Güncel uygulama iOS simülatörlerine gönderildi. ✅

## IPA 2.0.0+25 — bu sürümde yapılanlar

### Türkçe
- Ayarlar > Görünüm: yazı/arayüz boyutu (Küçük / Varsayılan / Büyük), varsayılan Varsayılan.
- Ayarlar > Genel: Titreşim/Ses/Bildirim → “Ses ve Bildirimler” alt sayfası.
- Giriş: “Şifremi unuttum”, e-posta ile sıfırlama, “Yeni Şifre Belirle” ekranı.
- Hesap profili: isim, avatar, giriş şifresi, yönetici PIN.
- Yönetici PIN: personel yoksa atlanır; personel varsa zorunlu; varsayılan 1234’ten zorla değiştirme; ilk personelde PIN oluşturma.
- Masalar: dolu önce (en yeni üstte), boş doğal sıra; TOPLAM / DOLU / BOŞ filtreleri.
- Menü: yeni kategori/ürün listenin başına eklenir.
- Koyu mod form/input kontrast iyileştirmeleri.
- Cari hesaplar menü ikonu güncellendi.
- Tamamlanan ödemelerde son 20 kayıt.

### English
- Settings > Appearance: UI scale (Small / Default / Large); default is Default.
- Settings: Vibration/Sound/Notifications moved to “Sound & Notifications” subpage.
- Login: Forgot password, reset email, set-new-password screen.
- Account profile: name, avatar, login password, admin PIN.
- Admin PIN: skipped with no staff; required with staff; force change from legacy 1234; create PIN when first staff is added.
- Tables: occupied first (newest on top), empty natural sort; TOTAL / OCCUPIED / EMPTY filters.
- Menu: new categories/items prepend to the list.
- Dark-mode form/input contrast fixes.
- Current accounts nav icon updated.
- Completed payments show the last 20 records.
