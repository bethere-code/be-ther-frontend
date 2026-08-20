import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../../explore/presentation/explore_providers.dart';
import '../../feed/presentation/feed_providers.dart';
import 'profile_providers.dart';

/// Usernames blocked this session (lowercase) — hide their posts immediately
/// while feed / explore / calendar caches catch up from the API.
final sessionBlockedUsernamesProvider =
    NotifierProvider<SessionBlockedUsernamesNotifier, Set<String>>(
  SessionBlockedUsernamesNotifier.new,
);

class SessionBlockedUsernamesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void block(String username) {
    final u = username.trim().toLowerCase();
    if (u.isEmpty || state.contains(u)) return;
    state = {...state, u};
  }

  void unblock(String username) {
    final u = username.trim().toLowerCase();
    if (u.isEmpty || !state.contains(u)) return;
    final next = {...state}..remove(u);
    state = next;
  }

  bool contains(String username) =>
      state.contains(username.trim().toLowerCase());
}

bool isAuthorSessionBlocked(Set<String> blocked, String? username) {
  final u = username?.trim().toLowerCase() ?? '';
  return u.isNotEmpty && blocked.contains(u);
}

/// Optimistic block: hide posts now, then persist. Rolls back the hide on API failure.
Future<void> blockUserOptimistic(WidgetRef ref, String username) async {
  final u = username.trim();
  if (u.isEmpty) throw Exception('Missing username');

  final session = ref.read(sessionBlockedUsernamesProvider.notifier);
  session.block(u);

  try {
    await ref.read(userRepositoryProvider).setBlocked(u, blocked: true);
    _invalidateAfterBlockChange(ref, u);
  } catch (_) {
    session.unblock(u);
    rethrow;
  }
}

Future<void> unblockUserOptimistic(WidgetRef ref, String username) async {
  final u = username.trim();
  if (u.isEmpty) throw Exception('Missing username');

  final session = ref.read(sessionBlockedUsernamesProvider.notifier);
  session.unblock(u);

  try {
    await ref.read(userRepositoryProvider).setBlocked(u, blocked: false);
    _invalidateAfterBlockChange(ref, u);
  } catch (_) {
    session.block(u);
    rethrow;
  }
}

void _invalidateAfterBlockChange(WidgetRef ref, String username) {
  ref.invalidate(feedProvider);
  ref.invalidate(exploreEventsProvider);
  ref.invalidate(blockedUsersProvider);
  ref.invalidate(profileViewProvider(username));
  ref.invalidate(profileCalendarProvider(username));
  ref.invalidate(profileEventsProvider(username));

  final me = ref.read(authNotifierProvider).user;
  final myUsername = (me?['username'] as String?)?.trim() ?? '';
  if (myUsername.isNotEmpty) {
    ref.invalidate(profileCalendarProvider(myUsername));
    ref.invalidate(profileEventsProvider(myUsername));
    ref.invalidate(profileMeProvider);
  }
}
