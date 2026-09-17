import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_providers.dart';

/// Badge via cheap unread-count + FCM; full list only when Alerts needs it.
///
/// Never force-fetch [notificationsProvider] on resume — that GET is heavy
/// (populate + enrich) and was the main chatty / RAM spike.
class NotificationSyncer {
  NotificationSyncer({required this.ref});

  final Ref ref;

  DateTime? _lastBadgeAt;
  static const _badgeDebounce = Duration(seconds: 2);

  /// Cold start: badge only.
  void start() {
    unawaited(refreshBadge());
  }

  /// Cheap badge refresh. Debounced so lifecycle flaps don't hammer the API.
  Future<void> refreshBadge({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastBadgeAt != null &&
        now.difference(_lastBadgeAt!) < _badgeDebounce) {
      return;
    }
    _lastBadgeAt = now;
    try {
      ref.invalidate(unreadNotificationCountProvider);
      await ref.read(unreadNotificationCountProvider.future);
    } catch (_) {}
  }

  /// Force full list GET — only call when Alerts is open / pull-to-refresh.
  Future<void> refreshList() async {
    try {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    } catch (_) {}
  }

  /// Mark list stale without fetching. Refetches only if something is watching.
  void softInvalidateList() {
    if (!ref.exists(notificationsProvider)) return;
    ref.invalidate(notificationsProvider);
  }

  /// Push open / rare “need everything” — badge always; list only if watched.
  Future<void> syncNow() async {
    await refreshBadge(force: true);
    if (ref.exists(notificationsProvider)) {
      await refreshList();
    } else {
      softInvalidateList();
    }
  }

  void stop() {}

  void dispose() {
    stop();
  }
}

final notificationSyncerProvider = Provider<NotificationSyncer>((ref) {
  return NotificationSyncer(ref: ref);
});
