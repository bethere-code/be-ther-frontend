import 'dart:async';
import 'dart:convert';
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
import '../utils/device_timezone.dart';
import 'push_local_notifications.dart';
import 'push_open.dart';

/// Background isolate entry — must be top-level.
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
  bool _handlersWired = false;
  bool _pushReady = false;
  String? _activeCityTopic;

  Future<void> startAfterAuth() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await PushLocalNotifications.ensureInitialized(
        onTap: _onLocalNotificationTap,
      );
      final messaging = FirebaseMessaging.instance;

      if (!_handlersWired) {
        _fgSub = FirebaseMessaging.onMessage.listen(_onForeground);
        _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
        _handlersWired = true;
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final enabled = _permissionGranted(settings.authorizationStatus);

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
      }

      if (!enabled) {
        _pushReady = false;
        return;
      }

      await _completePushRegistration(messaging);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        unawaited(_onOpened(initial));
      }
    } catch (_) {
      _pushReady = false;
    }
  }

  /// After user enables notifications in OS settings — no second prompt.
  Future<void> retryAfterAuthIfNeeded() async {
    if (kIsWeb || _pushReady) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await PushLocalNotifications.ensureInitialized(
        onTap: _onLocalNotificationTap,
      );
      final messaging = FirebaseMessaging.instance;

      if (!_handlersWired) {
        _fgSub = FirebaseMessaging.onMessage.listen(_onForeground);
        _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
        _handlersWired = true;
      }

      final settings = await messaging.getNotificationSettings();
      if (!_permissionGranted(settings.authorizationStatus)) {
        return;
      }

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
      }

      await _completePushRegistration(messaging);
    } catch (_) {
      _pushReady = false;
    }
  }

  bool _permissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _completePushRegistration(FirebaseMessaging messaging) async {
    await messaging.subscribeToTopic(broadcastTopic);

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }
    unawaited(_syncTimezone());

    await _tokenSub?.cancel();
    _tokenSub = messaging.onTokenRefresh.listen((t) {
      unawaited(_registerToken(t));
    });

    unawaited(_syncCityTopic());
    _pushReady = true;
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
    _handlersWired = false;
    _pushReady = false;
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

  Future<void> _syncTimezone() async {
    try {
      await _ref.read(apiClientProvider).patch(
        '/api/v1/users/me',
        data: {'timezone': deviceTimeZoneId()},
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

  void _onLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      unawaited(_navigateFromPushData(data));
    } catch (_) {}
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';

    if (type == 'unread_sync') {
      _ref.invalidate(unreadNotificationCountProvider);
      return;
    }

    final title = message.notification?.title ?? 'BE THER';
    final body = message.notification?.body;
    if (body != null && body.isNotEmpty) {
      await PushLocalNotifications.showForeground(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(data),
      );
    }

    _ref.invalidate(unreadNotificationCountProvider);
    _ref.read(notificationSyncerProvider).softInvalidateList();
  }

  Future<void> _onOpened(RemoteMessage message) async {
    await _navigateFromPushData(message.data);
  }

  Future<void> _navigateFromPushData(Map<String, dynamic> data) async {
    await _ref.read(notificationSyncerProvider).syncNow();
    final loc = locationFromPushData(data);
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

  Future<void> refreshCityTopic() => _syncCityTopic();
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
