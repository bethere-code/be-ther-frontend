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

final profileCalendarProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, username) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.calendar(username);
});
