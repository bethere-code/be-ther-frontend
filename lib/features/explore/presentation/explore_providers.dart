import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(ref.watch(apiClientProvider));
});

/// All public posts from the database, shaped for the explore grid.
final exploreEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.fetchEvents();
});
