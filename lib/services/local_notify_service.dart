import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Thin wrapper around local (device) notifications for in-app alerts.
class LocalNotifyService extends GetxService {
  static LocalNotifyService get to => Get.find();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int _seq = 1000;

  Future<LocalNotifyService> init() async {
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

  Future<void> showOrderAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'digital_menu_orders',
          'Bekleyen siparişler',
          channelDescription: 'Dijital menüden gelen masa siparişleri',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
