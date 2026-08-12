import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../feed/presentation/feed_providers.dart';
import '../data/user_repository.dart';
import '../domain/profile_user.dart';

export '../domain/profile_user.dart';

enum ProfileConnectionsMode { followers, following }

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});

final profileMeProvider = FutureProvider<ProfileUser>((ref) async {
  // Re-fetch when the session changes so a new login never inherits
  // another user's cached settings (e.g. calendarView).
  final token = ref.watch(authNotifierProvider.select((s) => s.accessToken));
  if (token == null || token.isEmpty) {
    throw StateError('Not authenticated');
  }
  final repo = ref.watch(userRepositoryProvider);
  return ProfileUser.fromJson(await repo.me());
});

/// Loads a profile for [username], or the authenticated user when null.
final profileViewProvider =
    FutureProvider.family<ProfileUser, String?>((ref, username) async {
  final token = ref.watch(authNotifierProvider.select((s) => s.accessToken));
  if (token == null || token.isEmpty) {
    throw StateError('Not authenticated');
  }
  final repo = ref.watch(userRepositoryProvider);
  final me = ProfileUser.fromJson(await repo.me());

  if (username == null ||
      username.isEmpty ||
      username == me.username) {
    return me;
  }

  return ProfileUser.fromJson(await repo.byUsername(username));
});

final profileCalendarProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, username) async {
    final token = ref.watch(authNotifierProvider.select((s) => s.accessToken));
    if (token == null || token.isEmpty) {
      throw StateError('Not authenticated');
    }
    final repo = ref.watch(userRepositoryProvider);
    return repo.calendar(username);
  },
);

final profileEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, username) async {
  final token = ref.watch(authNotifierProvider.select((s) => s.accessToken));
  if (token == null || token.isEmpty) {
    throw StateError('Not authenticated');
  }
  return ref.watch(userRepositoryProvider).events(username);
});

typedef ProfileConnectionsKey = ({String username, ProfileConnectionsMode mode});

final profileConnectionsProvider =
    FutureProvider.family<List<ProfileConnectionUser>, ProfileConnectionsKey>((
      ref,
      key,
    ) async {
  final token = ref.watch(authNotifierProvider.select((s) => s.accessToken));
  if (token == null || token.isEmpty) {
    throw StateError('Not authenticated');
  }
  final repo = ref.watch(userRepositoryProvider);
  final raw = key.mode == ProfileConnectionsMode.followers
      ? await repo.followers(key.username)
      : await repo.following(key.username);
  return raw.map(ProfileConnectionUser.fromJson).toList(growable: false);
});

void refreshProfileCaches(WidgetRef ref, Map<String, dynamic> user) {
  ref.read(authNotifierProvider.notifier).updateUser(user);
  ref.invalidate(profileMeProvider);
  ref.invalidate(profileViewProvider(null));
  ref.invalidate(feedProvider);
}
