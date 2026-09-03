import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/feed/data/places_repository.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../analytics/device_snapshot.dart';
import '../analytics/fcm_token.dart';
import '../background_tasks/notification_syncer.dart';
import '../network/api_client.dart';
import '../routing/app_router.dart';
import '../routing/deep_link_listener.dart';
import 'push_local_notifications.dart';
import 'push_open.dart';

/// Background isolate entry — must be top-level.
/// Do NOT show a local notification here when [message.notification] is set;
/// the OS already displayed it (single-notification rule).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep light — no Riverpod. Data-only silent sync has nothing to draw.
}

/// Registers FCM token, topics, and message handlers.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  bool _started = false;
  String? _activeCityTopic;

  Future<void> startAfterAuth() async {
    if (kIsWeb || _started) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _started = true;

    try {
      await PushLocalNotifications.ensureInitialized();
      final messaging = FirebaseMessaging.instance;

      // iOS + Android 13+: request permission once after login.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final enabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false, // we show via local notifications in foreground
          badge: true,
          sound: false,
        );
      }

      if (!enabled) return;

      await messaging.subscribeToTopic(broadcastTopic);

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      _tokenSub = messaging.onTokenRefresh.listen((t) {
        unawaited(_registerToken(t));
      });

      _fgSub = FirebaseMessaging.onMessage.listen(_onForeground);
      _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        unawaited(_onOpened(initial));
      }

      unawaited(_syncCityTopic());
    } catch (_) {
      // Push is best-effort — never block auth/shell.
      _started = false;
    }
  }

  Future<void> stopOnLogout() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _deleteToken(token);
      }
      await FirebaseMessaging.instance.unsubscribeFromTopic(broadcastTopic);
      if (_activeCityTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_activeCityTopic!);
        _activeCityTopic = null;
      }
    } catch (_) {}
    await _tokenSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _tokenSub = null;
    _fgSub = null;
    _openSub = null;
    _started = false;
    try {
      await FirebaseAnalytics.instance.setUserId(id: null);
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
  }

  Future<void> setAnalyticsUser(String? userId) async {
    try {
      await FirebaseAnalytics.instance.setUserId(id: userId);
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final dio = _ref.read(apiClientProvider);
    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : 'unknown';
    try {
      await dio.put(
        '/api/v1/users/me/fcm-devices',
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {}
  }

  Future<void> _deleteToken(String token) async {
    final dio = _ref.read(apiClientProvider);
    try {
      await dio.delete(
        '/api/v1/users/me/fcm-devices',
        data: {'token': token},
      );
    } catch (_) {}
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';

    if (type == 'unread_sync') {
      _ref.invalidate(unreadNotificationCountProvider);
      return;
    }

    // Single notification: OS does not show banners in foreground for FCM
    // notification payloads on Android; we display exactly one local notif.
    final title = message.notification?.title ?? 'BE THER';
    final body = message.notification?.body;
    if (body != null && body.isNotEmpty) {
      await PushLocalNotifications.showForeground(
        title: title,
        body: body,
        payload: data['notificationId']?.toString(),
      );
    }

    _ref.invalidate(unreadNotificationCountProvider);
    // Keep list fresh if user is already on Alerts.
    _ref.invalidate(notificationsProvider);
  }

  Future<void> _onOpened(RemoteMessage message) async {
    await _ref.read(notificationSyncerProvider).syncNow();
    final loc = locationFromPushData(message.data);
    if (loc == null || loc.isEmpty) return;
    final auth = _ref.read(authNotifierProvider);
    if (!auth.isReady || !auth.isAuthenticated) {
      _ref.read(pendingDeepLinkProvider.notifier).setPending(loc);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _ref.read(appRouterProvider).go(loc);
    });
  }

  /// Subscribe to `city_<slug>` from GPS reverse geocode when location allowed.
  Future<void> _syncCityTopic() async {
    try {
      final loc = await readLocationIfAllowed();
      if (loc == null) return;
      final places = PlacesRepository(_ref.read(apiClientProvider));
      final place = await places.reverseGeocode(lat: loc.lat, lng: loc.lng);
      final city = place.city.trim().isNotEmpty
          ? place.city
          : place.locality.trim();
      final topic = cityTopicFromName(city);
      if (topic == null) return;

      final messaging = FirebaseMessaging.instance;
      if (_activeCityTopic != null && _activeCityTopic != topic) {
        await messaging.unsubscribeFromTopic(_activeCityTopic!);
      }
      await messaging.subscribeToTopic(topic);
      _activeCityTopic = topic;

      try {
        await _ref.read(apiClientProvider).put(
          '/api/v1/users/me/fcm-city',
          data: {'city': city},
        );
      } catch (_) {}
    } catch (_) {}
  }

  /// Re-run city topic when app resumes (location may have changed).
  Future<void> refreshCityTopic() => _syncCityTopic();
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
