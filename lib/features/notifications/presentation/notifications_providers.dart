import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.list();
});
