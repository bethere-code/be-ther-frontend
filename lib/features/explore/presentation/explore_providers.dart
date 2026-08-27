import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/explore_repository.dart';
import '../domain/explore_page.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(ref.watch(apiClientProvider));
});

/// First page of public upcoming events for the explore grid.
final exploreEventsProvider = FutureProvider<ExplorePage>((ref) async {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.fetchEvents();
});

/// Later pages — same contract as [feedPageProvider].
final explorePageProvider =
    FutureProvider.family<ExplorePage, int>((ref, skip) async {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.fetchEvents(skip: skip);
});
