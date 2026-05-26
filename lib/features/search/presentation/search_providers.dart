import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

final searchResultsProvider =
    FutureProvider.family<SearchResult, ({String query, String? country, int skip})>((ref, params) async {
  final repo = ref.watch(searchRepositoryProvider);

  if (params.query.trim().isEmpty) {
    return SearchResult(items: [], nextSkip: null);
  }

  return repo.search(query: params.query, country: params.country, skip: params.skip);
});
