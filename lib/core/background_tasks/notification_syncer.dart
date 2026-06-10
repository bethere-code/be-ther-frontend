import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_providers.dart';

class NotificationSyncer {
  final Ref ref;
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(seconds: 15);

  NotificationSyncer({required this.ref});

  /// Start periodic notification sync
  void start() {
    // Initial sync
    _syncNotifications();

    // Periodic sync every 15 seconds
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _syncNotifications();
    });
  }

  /// Perform a single notification sync
  void _syncNotifications() {
    unawaited(_refreshNotifications());
  }

  Future<void> _refreshNotifications() async {
    try {
      final _ = await ref.refresh(notificationsProvider.future);
    } catch (_) {
      // Silently handle errors to avoid disrupting the app
    }
  }

  /// Stop the periodic sync
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Manually trigger a sync (e.g., on app resume)
  Future<void> syncNow() async {
    await _refreshNotifications();
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

final notificationSyncerProvider = Provider<NotificationSyncer>((ref) {
  return NotificationSyncer(ref: ref);
});

// Helper to ignore unawaited futures
void unawaited(Future<void>? future) {}
