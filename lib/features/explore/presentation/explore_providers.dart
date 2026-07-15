import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/explore_repository.dart';
import '../domain/explore_event.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(ref.watch(apiClientProvider));
});

/// Public upcoming events shaped for the explore grid.
final exploreEventsProvider = FutureProvider<List<ExploreEvent>>((ref) async {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.fetchEvents();
});
