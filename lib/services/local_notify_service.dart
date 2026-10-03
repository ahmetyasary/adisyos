import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:orderix/navigation/shell_nav.dart';
import 'package:orderix/services/settings_service.dart';

const _kPendingOrdersPayload = 'pending_orders';
const _kWakeChannel = 'digital_menu_orders_wake';
const _kSilentChannel = 'digital_menu_orders_wake_silent';

final Int64List _kOrderVibration = Int64List.fromList(
  [0, 400, 200, 400, 200, 600],
);

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
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      await _requestPermission();
      await _ensureChannels();
      await _openFromLaunchNotification();
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

  /// Max-importance channels so a locked device lights up for one alert.
  /// Sound is a channel property, so the silent path is a separate channel.
  Future<void> _ensureChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const led = Color(0xFFFF9500);
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _kWakeChannel,
        'Bekleyen siparişler',
        description: 'Dijital menüden gelen masa siparişleri',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _kOrderVibration,
        enableLights: true,
        ledColor: led,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _kSilentChannel,
        'Bekleyen siparişler (sessiz)',
        description: 'Ses kapalıyken titreşimli sipariş uyarısı',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        vibrationPattern: _kOrderVibration,
        enableLights: true,
        ledColor: led,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == _kPendingOrdersPayload) {
      ShellNav.open('pending_orders');
    }
  }

  Future<void> _openFromLaunchNotification() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp != true || response == null) return;
    _onNotificationTapped(response);
  }

  Future<void> showOrderAlert({
    required String title,
    required String body,
    bool systemSound = true,
  }) async {
    if (!_ready) return;

    final notifyOn = systemSound &&
        (!Get.isRegistered<SettingsService>() ||
            SettingsService.to.notifySoundsEnabled.value);
    final channelId = notifyOn ? _kWakeChannel : _kSilentChannel;

    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Bekleyen siparişler',
          channelDescription: 'Dijital menüden gelen masa siparişleri',
          importance: Importance.max,
          priority: Priority.max,
          playSound: notifyOn,
          enableVibration: true,
          vibrationPattern: _kOrderVibration,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: notifyOn
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          ticker: title,
          enableLights: true,
          ledColor: const Color(0xFFFF9500),
          ledOnMs: 800,
          ledOffMs: 400,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentBadge: true,
          presentSound: notifyOn,
          // Empty sound falls back to the system default, including when the
          // app is backgrounded and the screen is locked.
          sound: notifyOn ? '' : null,
          interruptionLevel: InterruptionLevel.active,
        ),
      );
      await _plugin.show(
        id: ++_seq,
        title: title,
        body: body,
        notificationDetails: details,
        payload: _kPendingOrdersPayload,
      );
    } catch (e) {
      if (kDebugMode) print('[LocalNotifyService] show: $e');
    }
  }
}
