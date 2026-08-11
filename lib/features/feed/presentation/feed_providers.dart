import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/posts_repository.dart';

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

  bool contains(String postId) => state.contains(postId.trim());
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
    FutureProvider.family<Map<String, dynamic>, String>((ref, postId) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchPost(postId);
});
