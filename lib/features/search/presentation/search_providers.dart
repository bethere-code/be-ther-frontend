import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/search_repository.dart';
import '../domain/search_post.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

/// Race-safe search: each (query, skip) watch gets its own CancelToken;
/// disposing the provider cancels the in-flight request.
final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchPage, ({String query, int skip})>((
      ref,
      params,
    ) async {
      final repo = ref.watch(searchRepositoryProvider);
      if (params.query.trim().isEmpty) return SearchPage.empty();

      final cancelToken = CancelToken();
      ref.onDispose(() {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('superseded');
        }
      });

      try {
        return await repo.search(
          query: params.query,
          skip: params.skip,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          // Keep previous data visible while a newer request is in flight.
          throw Exception('cancelled');
        }
        rethrow;
      }
    });
