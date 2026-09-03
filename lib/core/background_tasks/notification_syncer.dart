import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_providers.dart';

/// Keeps the alerts badge fresh via resume + push — no periodic poll.
///
/// Full list refresh on [syncNow] (app resume / alerts screen / push open).
class NotificationSyncer {
  NotificationSyncer({required this.ref});

  final Ref ref;

  /// One-shot badge refresh at start (no timer).
  void start() {
    unawaited(_refreshUnreadOnly());
  }

  Future<void> _refreshUnreadOnly() async {
    try {
      ref.invalidate(unreadNotificationCountProvider);
      await ref.read(unreadNotificationCountProvider.future);
    } catch (_) {}
  }

  Future<void> _refreshFullList() async {
    try {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    } catch (_) {}
  }

  void stop() {}

  /// App resume / alerts open / push tap — refresh badge + full list.
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
