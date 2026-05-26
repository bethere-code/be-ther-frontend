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
    try {
      // Ignore return value since this runs in background
      unawaited(ref.refresh(notificationsProvider.future));
    } catch (e) {
      // Silently handle errors to avoid disrupting the app
      // NotificationSyncer should be resilient to network issues
    }
  }

  /// Stop the periodic sync
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Manually trigger a sync (e.g., on app resume)
  Future<void> syncNow() async {
    try {
      await ref.refresh(notificationsProvider.future);
    } catch (e) {
      // Silently handle errors
    }
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
