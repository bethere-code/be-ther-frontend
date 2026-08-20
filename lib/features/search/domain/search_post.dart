import '../../explore/domain/explore_event.dart';

/// Paginated search results — items are explore-shaped events from the API.
class SearchPage {
  const SearchPage({required this.items, this.nextSkip});

  final List<ExploreEvent> items;
  final int? nextSkip;

  factory SearchPage.empty() => const SearchPage(items: []);

  factory SearchPage.fromJson(Map<String, dynamic> data) {
    final raw = data['items'] as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => ExploreEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final nextSkipRaw = data['nextSkip'];
    final nextSkip =
        nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');
    return SearchPage(items: List.unmodifiable(items), nextSkip: nextSkip);
  }
}
