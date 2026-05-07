import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/posts_repository.dart';

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  return PostsRepository(ref.watch(apiClientProvider));
});

final feedProvider = FutureProvider<FeedPage>((ref) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchFeed();
});
