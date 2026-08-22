import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:orderix/services/settings_service.dart';

/// Thin wrapper around local (device) notifications for in-app alerts.
class LocalNotifyService extends GetxService {
  static LocalNotifyService get to => Get.find();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int _seq = 1000;

  Future<LocalNotifyService> init() async {
    if (kIsWeb) {
      // Browser notifications need a different setup; skip for now.
      _ready = false;
      return this;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(settings: settings);
      await _requestPermission();
      await _ensureChannels();
      _ready = true;
    } catch (e) {
      if (kDebugMode) print('[LocalNotifyService] init: $e');
      _ready = false;
    }
    return this;
  }

  Future<void> _requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Separate channels so importance/sound can match user intensity.
  Future<void> _ensureChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'digital_menu_orders_low',
        'Bekleyen siparişler (düşük)',
        description: 'Dijital menü siparişleri — düşük ses',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'digital_menu_orders_medium',
        'Bekleyen siparişler (orta)',
        description: 'Dijital menü siparişleri — orta ses',
        importance: Importance.high,
        playSound: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'digital_menu_orders_high',
        'Bekleyen siparişler (yüksek)',
        description: 'Dijital menü siparişleri — yüksek ses',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  String _channelIdForIntensity(String intensity) {
    switch (intensity) {
      case 'low':
        return 'digital_menu_orders_low';
      case 'medium':
        return 'digital_menu_orders_medium';
      default:
        return 'digital_menu_orders_high';
    }
  }

  Importance _importanceFor(String intensity) {
    switch (intensity) {
      case 'low':
        return Importance.defaultImportance;
      case 'medium':
        return Importance.high;
      default:
        return Importance.max;
    }
  }

  Priority _priorityFor(String intensity) {
    switch (intensity) {
      case 'low':
        return Priority.defaultPriority;
      case 'medium':
        return Priority.high;
      default:
        return Priority.max;
    }
  }

  Future<void> showOrderAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;

    final notifyOn = !Get.isRegistered<SettingsService>() ||
        SettingsService.to.notifySoundsEnabled.value;
    final intensity = Get.isRegistered<SettingsService>()
        ? SettingsService.to.notifySoundIntensity.value
        : 'high';
    final channelId = _channelIdForIntensity(intensity);

    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Bekleyen siparişler',
          channelDescription: 'Dijital menüden gelen masa siparişleri',
          importance: _importanceFor(intensity),
          priority: _priorityFor(intensity),
          playSound: notifyOn,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: notifyOn,
          interruptionLevel: intensity == 'high'
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      );
      await _plugin.show(
        id: ++_seq,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      if (kDebugMode) print('[LocalNotifyService] show: $e');
    }
  }
}
