import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/search_repository.dart';
import '../domain/search_post.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

final searchResultsProvider =
    FutureProvider.family<SearchPage, ({String query, int skip})>((
      ref,
      params,
    ) async {
      final repo = ref.watch(searchRepositoryProvider);
      if (params.query.trim().isEmpty) return SearchPage.empty();
      return repo.search(query: params.query, skip: params.skip);
    });
