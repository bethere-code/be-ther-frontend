import '../../../core/utils/event_date_utils.dart';
import '../../explore/domain/explore_event.dart';

/// Match priority — mirrors backend `search.service.ts`.
abstract final class SearchRank {
  static const eventName = 4000;
  static const description = 3000;
  static const place = 2000;
  static const date = 1000;
  static const author = 500;
  static const pastPenalty = 100000;

  static int score(SearchPost post, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return post.isPast ? -pastPenalty : 0;

    var match = 0;
    // 1 — event name
    if (post.title.toLowerCase().contains(q)) {
      match = eventName;
    }
    // 2 — description
    final caption = post.caption?.toLowerCase() ?? '';
    if (caption.contains(q)) {
      match = match > description ? match : description;
    }
    // 3 — city / venue
    final city = post.city?.toLowerCase() ?? '';
    final venue = post.venue?.toLowerCase() ?? '';
    if (city.contains(q) || venue.contains(q)) {
      match = match > place ? match : place;
    }
    // 4 — date
    final dateRaw = post.dateRaw?.toLowerCase() ?? '';
    if (dateRaw.contains(q) || _dateVariantsContain(post.dateRaw, q)) {
      match = match > date ? match : date;
    }
    // Author / artist-style
    final authorHay =
        '${post.author?.username ?? ''} ${post.author?.displayName ?? ''}'
            .toLowerCase();
    if (authorHay.contains(q)) {
      match = match > author ? match : author;
    }

    return post.isPast ? match - pastPenalty : match;
  }

  static bool _dateVariantsContain(String? dateRaw, String q) {
    if (dateRaw == null || dateRaw.isEmpty) return false;
    final iso = EventDateUtils.parseEventDateToIso(dateRaw);
    if (iso == null) return false;
    // Query might be a human date that normalizes to the same ISO.
    final queryIso = EventDateUtils.parseEventDateToIso(q);
    return queryIso != null && queryIso == iso;
  }

  /// Stable sort: higher score first, then newer createdAt.
  static List<SearchPost> sort(List<SearchPost> items, String query) {
    final ranked = [...items]
      ..sort((a, b) {
        final byScore = score(b, query).compareTo(score(a, query));
        if (byScore != 0) return byScore;
        return b.createdAt.compareTo(a.createdAt);
      });
    return ranked;
  }
}

/// Typed search hit — mirrors enriched post payload from `/api/v1/posts/search`.
class SearchPost {
  const SearchPost({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.status,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    required this.isPast,
    required this.createdAt,
    this.caption,
    this.city,
    this.venue,
    this.dateRaw,
    this.time,
    this.ticketUrl,
    this.author,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String status;
  final String? caption;
  final String? city;
  final String? venue;
  final String? dateRaw;
  final String? time;
  final String? ticketUrl;
  final int likesCount;
  final int commentsCount;
  final bool liked;
  final bool isPast;
  final DateTime createdAt;
  final ExploreAuthor? author;

  String get statusLabel =>
      EventDateUtils.statusLabel(status: status, isPast: isPast);

  String get displayName =>
      author?.displayName.isNotEmpty == true
          ? author!.displayName
          : (author?.username ?? 'User');

  String get username => author?.username ?? '';

  String get avatarUrl => author?.avatarUrl ?? '';

  String? get badge => author?.badge;

  factory SearchPost.fromJson(Map<String, dynamic> json) {
    final details = json['eventDetails'] is Map<String, dynamic>
        ? json['eventDetails'] as Map<String, dynamic>
        : null;
    final dateRaw = details?['date'] as String?;
    final timeRaw = details?['time']?.toString();
    final createdRaw = json['createdAt'] as String?;
    final createdAt = DateTime.tryParse(createdRaw ?? '') ?? DateTime.now();

    return SearchPost(
      id: json['_id']?.toString() ?? '',
      title: json['location'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'going',
      caption: _trimOrNull(json['caption'] as String?),
      city: _trimOrNull(json['country'] as String?),
      venue: _trimOrNull(details?['venue'] as String?),
      dateRaw: dateRaw,
      time: _trimOrNull(timeRaw),
      ticketUrl: _trimOrNull(details?['ticketUrl'] as String?),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
      isPast: EventDateUtils.isPostPast(json),
      createdAt: createdAt,
      author: ExploreAuthor.tryParse(json['authorId'] ?? json['author']),
    );
  }

  static String? _trimOrNull(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}

class SearchPage {
  const SearchPage({required this.items, this.nextSkip});

  final List<SearchPost> items;
  final int? nextSkip;

  factory SearchPage.empty() => const SearchPage(items: []);

  factory SearchPage.fromJson(Map<String, dynamic> data, {String query = ''}) {
    final raw = data['items'] as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(SearchPost.fromJson)
        .toList();
    // Client-side safeguard — same priority as backend.
    final ranked = query.trim().isEmpty ? items : SearchRank.sort(items, query);
    final nextSkipRaw = data['nextSkip'];
    final nextSkip =
        nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');
    return SearchPage(items: List.unmodifiable(ranked), nextSkip: nextSkip);
  }
}
