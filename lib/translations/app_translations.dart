import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'tr_TR': {
          'app_name': 'Orderix',
          'home': 'Ana Sayfa',
          'tables': 'Masalar',
          'quick_sale': 'Hızlı Satış',
          'packages': 'Paketler',
          'online_orders': 'Online Sipariş',
          'inventory': 'Stoklar',
          'products': 'Ürünler',
          'staff': 'Çalışanlar',
          'reports': 'Raporlar',
          'settings': 'Ayarlar',
          'logout': 'Çıkış',
          'notifications': 'Bildirimler',
          'customer_service': 'Bize Ulaşın',
          'internet': 'İnternet',
          'server': 'Sunucu',
          'coming_soon': 'Yakında',

          // Table statuses
          'table': 'MASA',
          'available': 'Müsait',
          'occupied': 'Dolu',
          'reserved': 'Rezerve',
          'available_status': 'Müsait',
          'occupied_status': 'Dolu',

          // Menu categories (legacy keys)
          'menu': 'Menüler',
          'drinks': 'İçecekler',
          'desserts': 'Tatlılar',
          'appetizers': 'Atıştırmalıklar',
          'sandwiches': 'Sandviçler',
          'salads': 'Salatalar',
          'from_oven': 'Fırından',
          'special': 'Special',

          // Actions
          'search': 'Ara',
          'search_menu': 'Menüde Ara...',
          'new': 'Yeni',
          'gift': 'İkram',
          'exchange': 'İade',
          'split': 'Böl',
          'discount': 'İndirim',
          'print': 'Yazdır',
          'cancel': 'İptal',
          'move': 'Taşı',
          'pay': 'Ödeme Al',
          'save': 'Kaydet',
          'edit': 'Düzenle',
          'delete': 'Sil',
          'apply': 'Uygula',
          'close': 'Kapat',
          'calculate': 'Hesapla',
          'clear': 'Temizle',

          // Labels
          'total': 'Toplam',
          'subtotal': 'Ara Toplam',
          'total_amount': 'Toplam Tutar',
          'per_person': 'Kişi Başı',
          'table_label': 'Masa',
          'price': 'Fiyat',

          // Feedback
          'info': 'Bilgi',
          'warning': 'Uyarı',
          'error': 'Hata',
          'success': 'Başarılı',

          // Table management
          'add_table': 'Masa Ekle',
          'table_name': 'Masa Adı',
          'edit_table': 'Masa Düzenle',
          'delete_table': 'Masayı Sil',
          'delete_table_confirmation': '%s silinsin mi?',
          'no_tables': 'Masanız bulunmuyor. Sağ üstten ekleyiniz.',
          'yes': 'Evet',
          'no': 'Hayır',

          // Orders
          'no_orders_yet': 'Henüz sipariş yok',
          'table_already_empty': 'Masa zaten boş',
          'clear_table': 'Masayı Temizle',
          'clear_table_confirm': 'Mevcut siparişler silinecek. Onaylıyor musunuz?',
          'table_cleared': 'Masa temizlendi',
          'empty_no_print': 'Masa boş. Yazdırılacak sipariş yok.',
          'empty_no_move': 'Masa boş. Taşınacak sipariş yok.',
          'empty_no_pay': 'Masa boş. Ödeme alınamaz.',
          'empty_no_discount': 'Masa boş. İndirim uygulanamaz.',
          'empty_no_split': 'Masa boş. Hesap bölünemez.',

          // Split bill
          'split_bill': 'Hesap Böl',
          'how_many_people': 'Kaç kişiye bölünecek?',
          'bill_split_result': 'Hesap Bölümü',
          'valid_people_count': 'Geçerli bir kişi sayısı girin (minimum 2)',

          // Discount
          'apply_discount': 'İndirim Uygula',
          'discount_percent': 'İndirim Yüzdesi (%)',
          'discount_applied': 'İndirim uygulandı',
          'valid_discount': 'Geçerli bir indirim yüzdesi girin (1-100)',

          // Print
          'printing': 'Adisyon yazdırılıyor...',

          // Move
          'move_orders': 'Sipariş Taşı',
          'moved_to_table': 'masasına taşındı',

          // Payment
          'pay_title': 'Ödeme Al',
          'payment_received': 'Ödeme alındı. Masa temizlendi.',

          // Menu management
          'menu_management': 'Menü Yönetimi',
          'add_menu': 'Menü Ekle',
          'edit_menu': 'Menü Düzenle',
          'delete_menu': 'Menüyü Sil',
          'delete_menu_confirm': 'silinsin mi?',
          'no_menus': 'Menünüz bulunmuyor. Sağ üstten ekleyiniz.',
          'no_menu_defined': 'Tanımlı menü yok',
          'add_item': 'Ürün Ekle',
          'edit_item': 'Ürün Düzenle',
          'menu_name': 'Menü Adı',
          'item_name': 'Ürün Adı',
          'invalid_price': 'Geçersiz fiyat formatı',

          // Settings
          'company_name': 'Şirket Adı',
          'company_name_hint': 'Şirket adınızı girin',
          'default_discount_rate': 'İndirim Oranı (%)',
          'default_discount_hint': 'Örn: 10',
          'language': 'Dil',
          'save_settings': 'Kaydet',

          // Reports
          'reports_page': 'Raporlar',
          'daily_report': 'Günlük Rapor',
          'monthly_report': 'Aylık Rapor',
          'yearly_report': 'Yıllık Rapor',
          'daily_sales_title': 'Günlük Satış Raporu',
          'monthly_sales_title': 'Aylık Satış Raporu',
          'yearly_sales_title': 'Yıllık Satış Raporu',
          'total_sales': 'Toplam Satış',
          'sale_count': 'İşlem Sayısı',
          'top_items': 'En Çok Satılan',
          'no_sales_today': 'Bugün henüz satış yok',
          'no_sales': 'Henüz satış verisi yok',
          'hourly_sales': 'Saatlik Satışlar',

          // Auth
          'auth_subtitle': 'Restoran Yönetim Sistemi',
          'auth_email': 'E-posta',
          'auth_email_hint': 'ornek@sirket.com',
          'auth_email_required': 'E-posta adresi gerekli',
          'auth_email_invalid': 'Geçerli bir e-posta girin',
          'auth_password': 'Şifre',
          'auth_password_required': 'Şifre gerekli',
          'auth_password_short': 'Şifre en az 6 karakter olmalı',
          'auth_login': 'Giriş Yap',
          'auth_error_invalid': 'E-posta veya şifre hatalı.',
          'auth_error_unconfirmed': 'E-posta adresiniz henüz doğrulanmamış.',
          'auth_error_network': 'Bağlantı hatası. İnternetinizi kontrol edin.',
          'auth_error_generic': 'Giriş yapılamadı. Lütfen tekrar deneyin.',
          'auth_error_role_not_found': 'Kullanıcı rolü bulunamadı. Yöneticinizle iletişime geçin.',
          'auth_error_email_taken': 'Bu e-posta adresi zaten kayıtlı.',
          'auth_signup': 'Kayıt Ol',
          'auth_signup_title': 'Hesap Oluştur',
          'auth_signup_subtitle': 'Yeni hesabınızı oluşturun',
          'auth_confirm_password': 'Şifre Tekrar',
          'auth_confirm_password_hint': '••••••••',
          'auth_password_mismatch': 'Şifreler eşleşmiyor',
          'auth_no_account': 'Hesabınız yok mu?',
          'auth_have_account': 'Zaten hesabınız var mı?',
          'auth_signup_link': 'Kayıt Olun',
          'auth_login_link': 'Giriş Yapın',
          'auth_signup_success': 'Hesabınız oluşturuldu! E-postanızı doğrulayın.',
          'auth_signup_success_body': 'Lütfen e-posta kutunuzu kontrol edin ve hesabınızı doğruladıktan sonra giriş yapın.',
          'auth_back_to_login': 'Giriş Sayfasına Dön',

          // Notifications
          'new_order': 'Ödeme Alındı',
          'new_order_message': 'Yeni bir sipariş geldi. Lütfen kontrol edin.',
          'payment_notification': 'Ödeme Alındı',
          'recent_activity': 'Son Aktivite',
          'no_notifications': 'Henüz bildirim yok',

          // Kitchen
          'kitchen': 'Mutfak',
          'kitchen_display': 'Mutfak Ekranı',
          'pending': 'Bekliyor',
          'preparing': 'Hazırlanıyor',
          'ready': 'Hazır',

          // Inventory
          'inventory_mgmt': 'Stok Yönetimi',
          'out_of_stock': 'Stok tükendi',
          'low_stock': 'Az stok',

          // Staff
          'staff_report': 'Personel Raporu',
          'staff_performance': 'Personel Performansı',

          // QR
          'qr_code': 'QR Kod',
          'qr_preview': 'Menüyü Önizle',

          // Payment methods
          'pay_method': 'Ödeme Yöntemi',
          'pay_cash': 'Nakit',
          'pay_card': 'Kredi Kartı',
          'pay_transfer': 'Havale',
          'pay_breakdown': 'Ödeme Yöntemi Dağılımı',

          // Shift management
          'shift_mgmt': 'Vardiya Yönetimi',
          'clock_in': 'Giriş Yap',
          'clock_out': 'Çıkış Yap',
          'start_break': 'Mola Başlat',
          'end_break': 'Molayı Bitir',
          'on_shift': 'Vardiyada',
          'on_break': 'Molada',
          'off_shift': 'Dışarıda',

          // Dashboard
          'dashboard': 'Canlı Dashboard',
          'occupancy': 'Doluluk Oranı',
          'active_tables': 'Aktif Masalar',
        },
        'en_US': {
          'app_name': 'Orderix',
          'home': 'Home',
          'tables': 'Tables',
          'quick_sale': 'Quick Sale',
          'packages': 'Packages',
          'online_orders': 'Online Orders',
          'inventory': 'Inventory',
          'products': 'Products',
          'staff': 'Staff',
          'reports': 'Reports',
          'settings': 'Settings',
          'logout': 'Logout',
          'notifications': 'Notifications',
          'customer_service': 'Contact Us',
          'internet': 'Internet',
          'server': 'Server',
          'coming_soon': 'Coming Soon',

          // Table statuses
          'table': 'TABLE',
          'available': 'Available',
          'occupied': 'Occupied',
          'reserved': 'Reserved',
          'available_status': 'Available',
          'occupied_status': 'Occupied',

          // Menu categories
          'menu': 'Menu',
          'drinks': 'Drinks',
          'desserts': 'Desserts',
          'appetizers': 'Appetizers',
          'sandwiches': 'Sandwiches',
          'salads': 'Salads',
          'from_oven': 'From Oven',
          'special': 'Special',

          // Actions
          'search': 'Search',
          'search_menu': 'Search menu...',
          'new': 'New',
          'gift': 'Gift',
          'exchange': 'Return',
          'split': 'Split',
          'discount': 'Discount',
          'print': 'Print',
          'cancel': 'Cancel',
          'move': 'Move',
          'pay': 'Pay',
          'save': 'Save',
          'edit': 'Edit',
          'delete': 'Delete',
          'apply': 'Apply',
          'close': 'Close',
          'calculate': 'Calculate',
          'clear': 'Clear',

          // Labels
          'total': 'Total',
          'subtotal': 'Subtotal',
          'total_amount': 'Total Amount',
          'per_person': 'Per Person',
          'table_label': 'Table',
          'price': 'Price',

          // Feedback
          'info': 'Info',
          'warning': 'Warning',
          'error': 'Error',
          'success': 'Success',

          // Table management
          'add_table': 'Add Table',
          'table_name': 'Table Name',
          'edit_table': 'Edit Table',
          'delete_table': 'Delete Table',
          'delete_table_confirmation': 'Delete %s?',
          'no_tables': 'No tables found. Add one from the top right.',
          'yes': 'Yes',
          'no': 'No',

          // Orders
          'no_orders_yet': 'No orders yet',
          'table_already_empty': 'Table is already empty',
          'clear_table': 'Clear Table',
          'clear_table_confirm':
              'Current orders will be deleted. Do you confirm?',
          'table_cleared': 'Table cleared',
          'empty_no_print': 'Table is empty. Nothing to print.',
          'empty_no_move': 'Table is empty. Nothing to move.',
          'empty_no_pay': 'Table is empty. No payment possible.',
          'empty_no_discount': 'Table is empty. Cannot apply discount.',
          'empty_no_split': 'Table is empty. Cannot split.',

          // Split bill
          'split_bill': 'Split Bill',
          'how_many_people': 'How many people?',
          'bill_split_result': 'Bill Split',
          'valid_people_count': 'Enter a valid number (minimum 2)',

          // Discount
          'apply_discount': 'Apply Discount',
          'discount_percent': 'Discount Percentage (%)',
          'discount_applied': 'Discount applied',
          'valid_discount': 'Enter a valid discount percentage (1-100)',

          // Print
          'printing': 'Printing receipt...',

          // Move
          'move_orders': 'Move Orders',
          'moved_to_table': 'moved to table',

          // Payment
          'pay_title': 'Take Payment',
          'payment_received': 'Payment received. Table cleared.',

          // Menu management
          'menu_management': 'Menu Management',
          'add_menu': 'Add Menu',
          'edit_menu': 'Edit Menu',
          'delete_menu': 'Delete Menu',
          'delete_menu_confirm': 'delete?',
          'no_menus': 'No menus found. Add one from the top right.',
          'no_menu_defined': 'No menu defined',
          'add_item': 'Add Item',
          'edit_item': 'Edit Item',
          'menu_name': 'Menu Name',
          'item_name': 'Item Name',
          'invalid_price': 'Invalid price format',

          // Settings
          'company_name': 'Company Name',
          'company_name_hint': 'Enter your company name',
          'default_discount_rate': 'Default Discount Rate (%)',
          'default_discount_hint': 'e.g. 10',
          'language': 'Language',
          'save_settings': 'Save',

          // Reports
          'reports_page': 'Reports',
          'daily_report': 'Daily Report',
          'monthly_report': 'Monthly Report',
          'yearly_report': 'Yearly Report',
          'daily_sales_title': 'Daily Sales Report',
          'monthly_sales_title': 'Monthly Sales Report',
          'yearly_sales_title': 'Yearly Sales Report',
          'total_sales': 'Total Sales',
          'sale_count': 'Transactions',
          'top_items': 'Top Selling Items',
          'no_sales_today': 'No sales today yet',
          'no_sales': 'No sales data yet',
          'hourly_sales': 'Hourly Sales',

          // Auth
          'auth_subtitle': 'Restaurant Management System',
          'auth_email': 'Email',
          'auth_email_hint': 'you@company.com',
          'auth_email_required': 'Email is required',
          'auth_email_invalid': 'Enter a valid email address',
          'auth_password': 'Password',
          'auth_password_required': 'Password is required',
          'auth_password_short': 'Password must be at least 6 characters',
          'auth_login': 'Sign In',
          'auth_error_invalid': 'Incorrect email or password.',
          'auth_error_unconfirmed': 'Your email address has not been confirmed.',
          'auth_error_network': 'Connection error. Check your internet.',
          'auth_error_generic': 'Sign in failed. Please try again.',
          'auth_error_role_not_found': 'User role not found. Contact your administrator.',
          'auth_error_email_taken': 'This email address is already registered.',
          'auth_signup': 'Sign Up',
          'auth_signup_title': 'Create Account',
          'auth_signup_subtitle': 'Create your new account',
          'auth_confirm_password': 'Confirm Password',
          'auth_confirm_password_hint': '••••••••',
          'auth_password_mismatch': 'Passwords do not match',
          'auth_no_account': "Don't have an account?",
          'auth_have_account': 'Already have an account?',
          'auth_signup_link': 'Sign Up',
          'auth_login_link': 'Sign In',
          'auth_signup_success': 'Account created! Verify your email.',
          'auth_signup_success_body': 'Please check your inbox and verify your email address, then sign in.',
          'auth_back_to_login': 'Back to Sign In',

          // Notifications
          'new_order': 'Payment Received',
          'new_order_message': 'A new order has arrived. Please check.',
          'payment_notification': 'Payment Received',
          'recent_activity': 'Recent Activity',
          'no_notifications': 'No notifications yet',

          // Kitchen
          'kitchen': 'Kitchen',
          'kitchen_display': 'Kitchen Display',
          'pending': 'Pending',
          'preparing': 'Preparing',
          'ready': 'Ready',

          // Inventory
          'inventory_mgmt': 'Inventory',
          'out_of_stock': 'Out of stock',
          'low_stock': 'Low stock',

          // Staff
          'staff_report': 'Staff Report',
          'staff_performance': 'Staff Performance',

          // QR
          'qr_code': 'QR Code',
          'qr_preview': 'Preview Menu',

          // Payment methods
          'pay_method': 'Payment Method',
          'pay_cash': 'Cash',
          'pay_card': 'Card',
          'pay_transfer': 'Transfer',
          'pay_breakdown': 'Payment Method Breakdown',

          // Shift management
          'shift_mgmt': 'Shift Management',
          'clock_in': 'Clock In',
          'clock_out': 'Clock Out',
          'start_break': 'Start Break',
          'end_break': 'End Break',
          'on_shift': 'On Shift',
          'on_break': 'On Break',
          'off_shift': 'Off Duty',

          // Dashboard
          'dashboard': 'Live Dashboard',
          'occupancy': 'Occupancy Rate',
          'active_tables': 'Active Tables',
        },
      };
}
