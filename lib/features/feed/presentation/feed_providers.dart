import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/posts_repository.dart';
import '../domain/feed_post.dart';

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  return PostsRepository(ref.watch(apiClientProvider));
});

/// Post IDs removed this session — keeps feed / explore / search / profile
/// from showing a deleted event while caches refresh.
final deletedPostIdsProvider =
    NotifierProvider<DeletedPostIdsNotifier, Set<String>>(
  DeletedPostIdsNotifier.new,
);

class DeletedPostIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markDeleted(String postId) {
    final id = postId.trim();
    if (id.isEmpty) return;
    if (state.contains(id)) return;
    state = {...state, id};
  }

  void markDeletedMany(Iterable<String> postIds) {
    final next = {...state};
    var changed = false;
    for (final raw in postIds) {
      final id = raw.trim();
      if (id.isEmpty || next.contains(id)) continue;
      next.add(id);
      changed = true;
    }
    if (changed) state = next;
  }

  void restoreMany(Iterable<String> postIds) {
    final next = {...state};
    var changed = false;
    for (final raw in postIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      if (next.remove(id)) changed = true;
    }
    if (changed) state = next;
  }

  bool contains(String postId) => state.contains(postId.trim());
}

/// Author-hidden posts removed from feed/explore/search until caches refresh.
final discoveryHiddenPostIdsProvider =
    NotifierProvider<DiscoveryHiddenPostIdsNotifier, Set<String>>(
  DiscoveryHiddenPostIdsNotifier.new,
);

class DiscoveryHiddenPostIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markHidden(String postId) {
    final id = postId.trim();
    if (id.isEmpty || state.contains(id)) return;
    state = {...state, id};
  }

  void unhide(String postId) {
    final id = postId.trim();
    if (id.isEmpty || !state.contains(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }

  bool contains(String postId) => state.contains(postId.trim());
}

/// Newly created posts shown at the top of the feed until the next API refresh.
final feedLocalInsertsProvider =
    NotifierProvider<FeedLocalInsertsNotifier, List<FeedPost>>(
  FeedLocalInsertsNotifier.new,
);

class FeedLocalInsertsNotifier extends Notifier<List<FeedPost>> {
  @override
  List<FeedPost> build() => const [];

  void prepend(FeedPost post) {
    final id = post.id;
    if (id.isEmpty) {
      state = [post, ...state];
      return;
    }
    state = [post, ...state.where((p) => p.id != id)];
  }

  void removeWhere(bool Function(FeedPost post) test) {
    final next = state.where((p) => !test(p)).toList(growable: false);
    if (next.length == state.length) return;
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }
}

/// Edited events overlaid on cached lists until the next refresh.
final editedPostsProvider =
    NotifierProvider<EditedPostsNotifier, Map<String, FeedPost>>(
  EditedPostsNotifier.new,
);

class EditedPostsNotifier extends Notifier<Map<String, FeedPost>> {
  @override
  Map<String, FeedPost> build() => const {};

  void apply(FeedPost post) {
    final id = post.id.trim();
    if (id.isEmpty) return;
    state = {...state, id: post};
  }

  void revert(String postId) {
    final id = postId.trim();
    if (id.isEmpty || !state.containsKey(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final feedProvider = FutureProvider<FeedPage>((ref) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchFeed();
});

final feedPageProvider = FutureProvider.family<FeedPage, int>((ref, skip) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchFeed(skip: skip);
});

final sharedPostProvider =
    FutureProvider.family<FeedPost, String>((ref, postId) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchPost(postId);
});
