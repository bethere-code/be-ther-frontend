import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../../explore/presentation/explore_providers.dart';
import '../../feed/domain/feed_post.dart';
import '../../feed/presentation/calendar_status_store.dart';
import '../../feed/presentation/feed_providers.dart';
import 'profile_providers.dart';

/// Authors blocked this session — hide their content immediately (optimistic).
///
/// Pattern: tombstone by author identity (id + username) + purge known post IDs
/// from local caches; API sync afterward; rollback tombstones on failure.
class SessionBlockedAuthors {
  const SessionBlockedAuthors({
    this.usernames = const {},
    this.userIds = const {},
  });

  /// Lowercased usernames.
  final Set<String> usernames;

  /// Author user ids.
  final Set<String> userIds;

  bool get isEmpty => usernames.isEmpty && userIds.isEmpty;
}

final sessionBlockedAuthorsProvider =
    NotifierProvider<SessionBlockedAuthorsNotifier, SessionBlockedAuthors>(
  SessionBlockedAuthorsNotifier.new,
);

class SessionBlockedAuthorsNotifier extends Notifier<SessionBlockedAuthors> {
  @override
  SessionBlockedAuthors build() => const SessionBlockedAuthors();

  void block({String? username, String? userId}) {
    final u = username?.trim().toLowerCase() ?? '';
    final id = userId?.trim() ?? '';
    if (u.isEmpty && id.isEmpty) return;
    final alreadyUser = u.isEmpty || state.usernames.contains(u);
    final alreadyId = id.isEmpty || state.userIds.contains(id);
    if (alreadyUser && alreadyId) return;
    state = SessionBlockedAuthors(
      usernames: u.isEmpty ? state.usernames : {...state.usernames, u},
      userIds: id.isEmpty ? state.userIds : {...state.userIds, id},
    );
  }

  void unblock({String? username, String? userId}) {
    final u = username?.trim().toLowerCase() ?? '';
    final id = userId?.trim() ?? '';
    if (u.isEmpty && id.isEmpty) return;
    state = SessionBlockedAuthors(
      usernames: u.isEmpty
          ? state.usernames
          : ({...state.usernames}..remove(u)),
      userIds: id.isEmpty ? state.userIds : ({...state.userIds}..remove(id)),
    );
  }
}

bool isAuthorSessionBlocked(
  SessionBlockedAuthors blocked, {
  String? username,
  String? userId,
}) {
  if (blocked.isEmpty) return false;
  final id = userId?.trim() ?? '';
  if (id.isNotEmpty && blocked.userIds.contains(id)) return true;
  final u = username?.trim().toLowerCase() ?? '';
  return u.isNotEmpty && blocked.usernames.contains(u);
}

bool _matchesAuthor({
  required String blockedUsername,
  required String blockedUserId,
  String? username,
  String? userId,
}) {
  return isAuthorSessionBlocked(
    SessionBlockedAuthors(
      usernames: blockedUsername.isEmpty ? const {} : {blockedUsername},
      userIds: blockedUserId.isEmpty ? const {} : {blockedUserId},
    ),
    username: username,
    userId: userId,
  );
}

/// Optimistic block: purge local caches now, persist, soft-refresh. Rollback on fail.
Future<void> blockUserOptimistic(
  WidgetRef ref, {
  required String username,
  String? authorId,
  String? triggerPostId,
}) async {
  final u = username.trim();
  final id = authorId?.trim() ?? '';
  if (u.isEmpty && id.isEmpty) throw Exception('Missing user');

  final session = ref.read(sessionBlockedAuthorsProvider.notifier);
  session.block(username: u, userId: id);

  final purged = _purgeLocalAuthorContent(
    ref,
    username: u.toLowerCase(),
    userId: id,
    triggerPostId: triggerPostId,
  );

  try {
    // API block is by username.
    if (u.isEmpty) throw Exception('Missing username');
    await ref.read(userRepositoryProvider).setBlocked(u, blocked: true);
    _invalidateAfterBlockChange(ref, u);
  } catch (_) {
    session.unblock(username: u, userId: id);
    _restorePurged(ref, purged);
    rethrow;
  }
}

Future<void> unblockUserOptimistic(
  WidgetRef ref, {
  required String username,
  String? authorId,
}) async {
  final u = username.trim();
  final id = authorId?.trim() ?? '';
  if (u.isEmpty) throw Exception('Missing username');

  final session = ref.read(sessionBlockedAuthorsProvider.notifier);
  session.unblock(username: u, userId: id);

  try {
    await ref.read(userRepositoryProvider).setBlocked(u, blocked: false);
    _invalidateAfterBlockChange(ref, u);
  } catch (_) {
    session.block(username: u, userId: id);
    rethrow;
  }
}

class _PurgeSnapshot {
  _PurgeSnapshot({
    required this.postIds,
    required this.calendarBefore,
    required this.localInsertsBefore,
  });

  final Set<String> postIds;
  final Map<String, String?> calendarBefore;
  final List<FeedPost> localInsertsBefore;
}

_PurgeSnapshot _purgeLocalAuthorContent(
  WidgetRef ref, {
  required String username,
  required String userId,
  String? triggerPostId,
}) {
  final postIds = <String>{};
  final trigger = triggerPostId?.trim() ?? '';
  if (trigger.isNotEmpty) postIds.add(trigger);

  final feed = ref.read(feedProvider).asData?.value;
  if (feed != null) {
    for (final post in feed.items) {
      if (_matchesAuthor(
        blockedUsername: username,
        blockedUserId: userId,
        username: post.author.username,
        userId: post.author.id,
      )) {
        final pid = post.id.trim();
        if (pid.isNotEmpty) postIds.add(pid);
      }
    }
  }

  final inserts = ref.read(feedLocalInsertsProvider);
  for (final post in inserts) {
    if (_matchesAuthor(
      blockedUsername: username,
      blockedUserId: userId,
      username: post.author.username,
      userId: post.author.id,
    )) {
      final pid = post.id.trim();
      if (pid.isNotEmpty) postIds.add(pid);
    }
  }

  final explore = ref.read(exploreEventsProvider).asData?.value;
  if (explore != null) {
    for (final event in explore) {
      if (_matchesAuthor(
        blockedUsername: username,
        blockedUserId: userId,
        username: event.author?.username,
        userId: event.author?.id,
      )) {
        final pid = event.id.trim();
        if (pid.isNotEmpty) postIds.add(pid);
      }
    }
  }

  final calendar = ref.read(calendarStatusStoreProvider.notifier);
  final calendarBefore = <String, String?>{};
  final calState = ref.read(calendarStatusStoreProvider);
  for (final postId in postIds) {
    if (calState.containsKey(postId)) {
      calendarBefore[postId] = calState[postId];
    }
    calendar.setStatus(postId, null);
  }

  final localBefore = List<FeedPost>.of(inserts);
  ref.read(feedLocalInsertsProvider.notifier).removeWhere(
        (p) => _matchesAuthor(
          blockedUsername: username,
          blockedUserId: userId,
          username: p.author.username,
          userId: p.author.id,
        ),
      );

  ref.read(deletedPostIdsProvider.notifier).markDeletedMany(postIds);

  return _PurgeSnapshot(
    postIds: postIds,
    calendarBefore: calendarBefore,
    localInsertsBefore: localBefore,
  );
}

void _restorePurged(WidgetRef ref, _PurgeSnapshot purged) {
  ref.read(deletedPostIdsProvider.notifier).restoreMany(purged.postIds);
  final calendar = ref.read(calendarStatusStoreProvider.notifier);
  purged.calendarBefore.forEach(calendar.setStatus);
  final inserts = ref.read(feedLocalInsertsProvider.notifier);
  for (final post in purged.localInsertsBefore.reversed) {
    inserts.prepend(post);
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
