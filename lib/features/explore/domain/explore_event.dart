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
    final username = json['username']?.toString().trim() ?? '';
    final displayName = json['displayName']?.toString().trim();
    return ExploreAuthor(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      displayName:
          (displayName != null && displayName.isNotEmpty) ? displayName : username,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      badge: json['badge']?.toString(),
    );
  }

  static ExploreAuthor? tryParse(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final parsed = ExploreAuthor.fromJson(raw);
      return parsed.username.isEmpty ? null : parsed;
    }
    if (raw is Map) {
      final parsed = ExploreAuthor.fromJson(Map<String, dynamic>.from(raw));
      return parsed.username.isEmpty ? null : parsed;
    }
    return null;
  }

  static ExploreAuthor fromFeedAuthor({
    required String id,
    required String username,
    required String displayName,
    required String avatarUrl,
    String? badge,
  }) {
    return ExploreAuthor(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      badge: badge,
    );
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
    this.calendarStatus,
    required this.isPast,
    this.place,
    this.address,
    this.country,
    this.venue,
    this.dateRaw,
    this.time,
    this.ticketUrl,
    this.caption,
    this.author,
    this.liked = false,
    this.bookmarked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? place;
  /// Places `formattedAddress` when the event was created (no fallbacks).
  final String? address;
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
  final String? calendarStatus;
  final bool isPast;
  final int likesCount;
  final int commentsCount;

  String get postId => id;

  String get heroTag => 'explore-event-image-$id';

  /// Explore/search sheet location row — Places `formattedAddress` only.
  String get placeLabel {
    final addressLabel = address?.trim() ?? '';
    if (addressLabel.isEmpty) return '';
    if (addressLabel.toLowerCase() == title.trim().toLowerCase()) return '';
    return addressLabel;
  }

  /// Grid tile: first segment of the full address / place line.
  String get placeShort {
    final full = placeLabel.trim();
    if (full.isEmpty) return '';
    // "Name · full address" → prefer the street address after the separator.
    final dot = full.indexOf(' · ');
    if (dot != -1) {
      final after = full.substring(dot + 3).trim();
      if (after.isNotEmpty) {
        final comma = after.indexOf(',');
        return comma == -1 ? after : after.substring(0, comma).trim();
      }
    }
    final comma = full.indexOf(',');
    if (comma == -1) return full;
    return full.substring(0, comma).trim();
  }

  bool get hasTicketUrl =>
      ticketUrl != null && ticketUrl!.trim().isNotEmpty && !isPast;

  bool get showAttendees => attendees > 0;

  /// e.g. "Jul 19, 2026 · 6:00 PM"
  String get dateTimeLabel {
    final datePart = _formatDate(dateRaw);
    final timePart = formattedTime;
    if (datePart == null && (timePart == null || timePart.isEmpty)) return '';
    if (datePart != null && timePart != null && timePart.isNotEmpty) {
      return '$datePart · $timePart';
    }
    return datePart ?? timePart ?? '';
  }

  String? get formattedDateOnly => _formatDate(dateRaw);

  /// `HH:mm` / already-localized → `h:mm AM/PM`.
  String? get formattedTime => EventDateUtils.formatTime12h(time);

  factory ExploreEvent.fromJson(Map<String, dynamic> json) {
    final id =
        json['postId']?.toString() ?? json['_id']?.toString() ?? '';
    final details = json['eventDetails'] is Map<String, dynamic>
        ? json['eventDetails'] as Map<String, dynamic>
        : null;

    // Explore API uses `title`/`date`/`venue`; post/search fallbacks use
    // `location` and nested `eventDetails`.
    final title = _nullableTrim(json['title'] as String?) ??
        _nullableTrim(json['location'] as String?) ??
        '';
    final dateRaw = (json['date'] as String?) ??
        (details?['date'] as String?);
    final timeRaw =
        json['time']?.toString() ?? details?['time']?.toString();
    final venue = _nullableTrim(json['venue'] as String?) ??
        _nullableTrim(details?['venue'] as String?);
    final ticketUrl = _nullableTrim(json['ticketUrl'] as String?) ??
        _nullableTrim(details?['ticketUrl'] as String?);

    final eventLocation = details?['eventLocation'] is Map<String, dynamic>
        ? details!['eventLocation'] as Map<String, dynamic>
        : (json['eventLocation'] is Map<String, dynamic>
            ? json['eventLocation'] as Map<String, dynamic>
            : null);
    final address = _resolveFormattedAddress(
      jsonAddress: _nullableTrim(json['address'] as String?),
      eventLocation: eventLocation,
    );

    final isPast = EventDateUtils.isEventPast(
      dateRaw: dateRaw,
      timeRaw: timeRaw,
    );

    final likesCount = (json['likesCount'] as num?)?.toInt() ?? 0;
    final commentsCount = (json['commentsCount'] as num?)?.toInt() ?? 0;
    final attendees = (json['attendees'] as num?)?.toInt() ??
        (json['calendarCount'] as num?)?.toInt() ??
        0;

    return ExploreEvent(
      id: id,
      title: title,
      imageUrl: json['image'] as String? ?? json['imageUrl'] as String? ?? '',
      place: _nullableTrim(json['place'] as String?),
      address: address,
      country: _nullableTrim(json['country'] as String?),
      venue: venue,
      dateRaw: dateRaw,
      time: _nullableTrim(timeRaw),
      ticketUrl: ticketUrl,
      caption: _nullableTrim(json['caption'] as String?),
      attendees: attendees,
      trending: json['trending'] as bool? ?? likesCount >= 5,
      status: json['status'] as String? ?? '',
      author: ExploreAuthor.tryParse(json['authorId'] ?? json['author']),
      liked: json['liked'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      inCalendar: json['inCalendar'] as bool? ?? false,
      calendarStatus: json['calendarStatus'] as String? ??
          ((json['inCalendar'] as bool? ?? false) ? 'going' : null),
      isPast: isPast,
      likesCount: likesCount,
      commentsCount: commentsCount,
    );
  }

  /// Places `formattedAddress` only — never venue/country/tag stitching.
  static String? _resolveFormattedAddress({
    required String? jsonAddress,
    required Map<String, dynamic>? eventLocation,
  }) {
    final fromLocation =
        _nullableTrim(eventLocation?['formattedAddress'] as String?);
    if (fromLocation != null) return fromLocation;
    return jsonAddress;
  }

  ExploreEvent copyWith({
    bool? inCalendar,
    String? calendarStatus,
    int? likesCount,
    int? commentsCount,
    bool? liked,
    ExploreAuthor? author,
  }) {
    return ExploreEvent(
      id: id,
      title: title,
      imageUrl: imageUrl,
      place: place,
      address: address,
      country: country,
      venue: venue,
      dateRaw: dateRaw,
      time: time,
      ticketUrl: ticketUrl,
      caption: caption,
      attendees: attendees,
      trending: trending,
      status: status,
      author: author ?? this.author,
      liked: liked ?? this.liked,
      bookmarked: bookmarked,
      inCalendar: inCalendar ?? this.inCalendar,
      calendarStatus: calendarStatus ?? this.calendarStatus,
      isPast: isPast,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
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
