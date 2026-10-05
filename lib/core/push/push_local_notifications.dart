import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Foreground-only local notifications.
///
/// Background / killed: OS shows the FCM `notification` payload once.
/// We must NOT show a local notification in those states (avoids doubles).
class PushLocalNotifications {
  PushLocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const androidChannel = AndroidNotificationChannel(
    'be_ther_alerts',
    'BE THER Alerts',
    description: 'Follows, likes, comments, and announcements',
    importance: Importance.high,
  );

  static bool _ready = false;
  static void Function(String? payload)? _onTap;

  static Future<void> ensureInitialized({
    void Function(String? payload)? onTap,
  }) async {
    if (onTap != null) {
      _onTap = onTap;
    }
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_bether');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        _onTap?.call(details.payload);
      },
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _onTap?.call(launch?.notificationResponse?.payload);
    }

    _ready = true;
  }

  /// Show only while the app is in the foreground.
  static Future<void> showForeground({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await ensureInitialized();
    final payload = data == null ? null : jsonEncode(data);
    await _plugin.show(
      id: title.hashCode ^ body.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_bether',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
