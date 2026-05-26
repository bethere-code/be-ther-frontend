import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  try {
    return await repo.list();
  } catch (e) {
    return [];
  }
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  try {
    return notifications
        .where((n) => n['read'] != true)
        .length;
  } catch (e) {
    return 0;
  }
});
