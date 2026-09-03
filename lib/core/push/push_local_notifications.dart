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
    description: 'Follows, wishlist, calendar, and announcements',
    importance: Importance.high,
  );

  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
    _ready = true;
  }

  /// Show only while the app is in the foreground.
  static Future<void> showForeground({
    required String title,
    required String body,
    String? payload,
  }) async {
    await ensureInitialized();
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
          icon: '@mipmap/ic_launcher',
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
