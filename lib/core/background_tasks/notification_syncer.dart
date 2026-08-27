import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_providers.dart';

/// Keeps the alerts badge fresh without hammering the full notifications list.
///
/// Phase 1 interim (FCM replaces this in Phase 2.1):
/// - Unread-count poll every [_unreadInterval] (badge only)
/// - Full list refresh on [syncNow] (app resume / alerts screen)
class NotificationSyncer {
  NotificationSyncer({required this.ref});

  final Ref ref;
  Timer? _unreadTimer;

  /// Was 15s full-list poll (~67 req/s at 1k users). Now badge-only.
  static const Duration _unreadInterval = Duration(seconds: 60);

  /// Start badge polling. Does not fetch the full notifications list.
  void start() {
    unawaited(_refreshUnreadOnly());
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(_unreadInterval, (_) {
      unawaited(_refreshUnreadOnly());
    });
  }

  Future<void> _refreshUnreadOnly() async {
    try {
      ref.invalidate(unreadNotificationCountProvider);
      await ref.read(unreadNotificationCountProvider.future);
    } catch (_) {
      // Silently handle errors to avoid disrupting the app
    }
  }

  Future<void> _refreshFullList() async {
    try {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    } catch (_) {
      // Silently handle errors to avoid disrupting the app
    }
  }

  void stop() {
    _unreadTimer?.cancel();
    _unreadTimer = null;
  }

  /// App resume / alerts open — refresh badge + full list.
  Future<void> syncNow() async {
    await Future.wait([
      _refreshUnreadOnly(),
      _refreshFullList(),
    ]);
  }

  void dispose() {
    stop();
  }
}

final notificationSyncerProvider = Provider<NotificationSyncer>((ref) {
  return NotificationSyncer(ref: ref);
});
