import 'explore_event.dart';

/// Paginated explore results — same shape as search pages.
class ExplorePage {
  const ExplorePage({required this.items, this.nextSkip});

  final List<ExploreEvent> items;
  final int? nextSkip;

  factory ExplorePage.empty() => const ExplorePage(items: []);

  factory ExplorePage.fromJson(Map<String, dynamic> data) {
    final raw = data['items'] as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => ExploreEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final nextSkipRaw = data['nextSkip'];
    final nextSkip =
        nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');
    return ExplorePage(items: List.unmodifiable(items), nextSkip: nextSkip);
  }
}
