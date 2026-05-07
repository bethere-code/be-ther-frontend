import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(ref.watch(apiClientProvider));
});

final exploreEventsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.fetchEvents(type);
});
