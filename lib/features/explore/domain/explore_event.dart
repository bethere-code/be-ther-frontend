import 'package:intl/intl.dart';

import '../../../core/utils/event_date_utils.dart';

class ExploreAuthor {
  const ExploreAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.badge,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String? badge;

  factory ExploreAuthor.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String? ?? '';
    final displayName = (json['displayName'] as String?)?.trim();
    return ExploreAuthor(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      displayName:
          (displayName != null && displayName.isNotEmpty) ? displayName : username,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      badge: json['badge'] as String?,
    );
  }

  static ExploreAuthor? tryParse(dynamic raw) {
    if (raw is Map<String, dynamic>) return ExploreAuthor.fromJson(raw);
    if (raw is Map) {
      return ExploreAuthor.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

class ExploreEvent {
  const ExploreEvent({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.attendees,
    required this.trending,
    required this.status,
    required this.inCalendar,
    required this.isPast,
    this.place,
    this.country,
    this.venue,
    this.dateRaw,
    this.time,
    this.ticketUrl,
    this.caption,
    this.author,
    this.liked = false,
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? place;
  final String? country;
  final String? venue;
  final String? dateRaw;
  final String? time;
  final String? ticketUrl;
  final String? caption;
  final int attendees;
  final bool trending;
  final String status;
  final ExploreAuthor? author;
  final bool liked;
  final bool bookmarked;
  final bool inCalendar;
  final bool isPast;

  String get postId => id;

  String get heroTag => 'explore-event-image-$id';

  /// Full place string for sheet / share (deduped).
  String get placeLabel {
    final candidates = <String>[
      place?.trim() ?? '',
      country?.trim() ?? '',
      venue?.trim() ?? '',
    ];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      if (title.isNotEmpty && c.toLowerCase() == title.toLowerCase()) continue;
      return c;
    }
    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }
    return '';
  }

  /// Grid tile: text before the first comma (e.g. "AMB cinemas, Hyd…" → "AMB cinemas").
  String get placeShort {
    final full = placeLabel.trim();
    if (full.isEmpty) return '';
    final comma = full.indexOf(',');
    if (comma == -1) return full;
    return full.substring(0, comma).trim();
  }

  bool get hasTicketUrl =>
      ticketUrl != null && ticketUrl!.trim().isNotEmpty && !isPast;

  bool get showAttendees => attendees > 0;

  /// e.g. "Jul 19, 2026 · 18:00"
  String get dateTimeLabel {
    final datePart = _formatDate(dateRaw);
    final timePart = time?.trim();
    if (datePart == null && (timePart == null || timePart.isEmpty)) return '';
    if (datePart != null && timePart != null && timePart.isNotEmpty) {
      return '$datePart · $timePart';
    }
    return datePart ?? timePart ?? '';
  }

  String? get formattedDateOnly => _formatDate(dateRaw);

  factory ExploreEvent.fromJson(Map<String, dynamic> json) {
    final id =
        json['postId']?.toString() ?? json['_id']?.toString() ?? '';
    final dateRaw = json['date'] as String?;
    final timeRaw = json['time']?.toString();
    final apiPast = json['isPast'] ?? json['isEventPast'];
    final isPast = apiPast is bool
        ? apiPast
        : EventDateUtils.isEventPast(dateRaw: dateRaw, timeRaw: timeRaw);

    return ExploreEvent(
      id: id,
      title: json['title'] as String? ?? '',
      imageUrl: json['image'] as String? ?? json['imageUrl'] as String? ?? '',
      place: _nullableTrim(json['place'] as String?),
      country: _nullableTrim(json['country'] as String?),
      venue: _nullableTrim(json['venue'] as String?),
      dateRaw: dateRaw,
      time: _nullableTrim(timeRaw),
      ticketUrl: _nullableTrim(json['ticketUrl'] as String?),
      caption: json['caption'] as String?,
      attendees: (json['attendees'] as num?)?.toInt() ?? 0,
      trending: json['trending'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      author: ExploreAuthor.tryParse(json['authorId'] ?? json['author']),
      liked: json['liked'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      inCalendar: json['inCalendar'] as bool? ?? false,
      isPast: isPast,
    );
  }

  ExploreEvent copyWith({bool? inCalendar}) {
    return ExploreEvent(
      id: id,
      title: title,
      imageUrl: imageUrl,
      place: place,
      country: country,
      venue: venue,
      dateRaw: dateRaw,
      time: time,
      ticketUrl: ticketUrl,
      caption: caption,
      attendees: attendees,
      trending: trending,
      status: status,
      author: author,
      liked: liked,
      bookmarked: bookmarked,
      inCalendar: inCalendar ?? this.inCalendar,
      isPast: isPast,
    );
  }

  static String? _nullableTrim(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static String? _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.length >= 10) {
      final iso = DateTime.tryParse(trimmed.substring(0, 10));
      if (iso != null) return DateFormat('MMM d, y').format(iso);
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return DateFormat('MMM d, y').format(parsed);
    return trimmed;
  }
}
