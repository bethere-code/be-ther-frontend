import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});

final profileMeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.me();
});

/// Loads a profile for [username], or the authenticated user when null.
final profileViewProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, username) async {
  final repo = ref.watch(userRepositoryProvider);
  final me = await repo.me();
  final meUsername = me['username'] as String? ?? '';

  if (username == null || username.isEmpty || username == meUsername) {
    return me;
  }

  return repo.byUsername(username);
});

final profileCalendarProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, username) async {
    final repo = ref.watch(userRepositoryProvider);
    return repo.calendar(username);
  },
);
