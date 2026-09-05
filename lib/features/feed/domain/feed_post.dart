import '../../../core/media/cover_aspect.dart';
import '../../../core/utils/event_date_utils.dart';

class FeedPostAuthor {
  const FeedPostAuthor({
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

  factory FeedPostAuthor.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FeedPostAuthor(
        id: '',
        username: '',
        displayName: 'User',
        avatarUrl: '',
      );
    }
    final username = (json['username'] as String?)?.trim() ?? '';
    final displayName = (json['displayName'] as String?)?.trim();
    return FeedPostAuthor(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      displayName: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (username.isNotEmpty ? username : 'User'),
      avatarUrl: json['avatarUrl'] as String? ?? '',
      badge: json['badge'] as String?,
    );
  }
}

class FeedEventPlace {
  const FeedEventPlace({
    this.formattedAddress = '',
    this.placeId = '',
    this.name = '',
    this.lat,
    this.lng,
  });

  final String formattedAddress;
  final String placeId;
  final String name;
  final double? lat;
  final double? lng;

  factory FeedEventPlace.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeedEventPlace();
    double? numOf(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }
    return FeedEventPlace(
      formattedAddress: (json['formattedAddress'] as String?)?.trim() ?? '',
      placeId: json['placeId']?.toString() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      lat: numOf(json['lat']),
      lng: numOf(json['lng']),
    );
  }

  bool get isEmpty =>
      formattedAddress.isEmpty && placeId.isEmpty && name.isEmpty;
}

class FeedEventDetails {
  const FeedEventDetails({
    this.date,
    this.time,
    this.venue,
    this.ticketUrl,
    this.eventLocation = const FeedEventPlace(),
  });

  final String? date;
  final String? time;
  final String? venue;
  final String? ticketUrl;
  final FeedEventPlace eventLocation;

  bool get isEmpty =>
      (date == null || date!.trim().isEmpty) &&
      (time == null || time!.trim().isEmpty) &&
      (venue == null || venue!.trim().isEmpty) &&
      (ticketUrl == null || ticketUrl!.trim().isEmpty) &&
      eventLocation.isEmpty;

  factory FeedEventDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeedEventDetails();
    final locRaw = json['eventLocation'];
    return FeedEventDetails(
      date: json['date'] as String?,
      time: json['time'] as String?,
      venue: json['venue'] as String?,
      ticketUrl: json['ticketUrl'] as String?,
      eventLocation: locRaw is Map<String, dynamic>
          ? FeedEventPlace.fromJson(locRaw)
          : locRaw is Map
              ? FeedEventPlace.fromJson(Map<String, dynamic>.from(locRaw))
              : const FeedEventPlace(),
    );
  }
}

/// Typed feed / shared / profile-events post. Parse once at the API boundary.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.location,
    required this.imageUrl,
    required this.caption,
    required this.liked,
    required this.likesCount,
    required this.commentsCount,
    required this.calendarCount,
    required this.inCalendar,
    required this.createdAt,
    this.calendarStatus,
    this.status,
    this.eventDetails = const FeedEventDetails(),
    this.isEventPastApi,
    this.editedAt,
    this.usesDefaultCover = false,
    this.coverAspectRatio,
  });

  final String id;
  final FeedPostAuthor author;
  final String location;
  final String imageUrl;
  final String caption;
  final bool liked;
  final int likesCount;
  final int commentsCount;
  final int calendarCount;
  final bool inCalendar;
  final String? calendarStatus;
  /// Author-side status on own posts (`going` / `interested`).
  final String? status;
  final FeedEventDetails eventDetails;
  final DateTime createdAt;
  final bool? isEventPastApi;
  final DateTime? editedAt;
  final bool usesDefaultCover;
  /// Cover width÷height as uploaded; null on legacy posts.
  final double? coverAspectRatio;

  /// Layout slot for wide covers (feed / sheets).
  double get displayCoverAspect => resolveCoverAspectRatio(
        stored: coverAspectRatio,
        usesDefaultCover: usesDefaultCover,
      );

  bool get isEdited => editedAt != null;

  bool get isPast {
    final date = eventDetails.date;
    if (date != null && date.trim().isNotEmpty) {
      return EventDateUtils.isEventPast(
        dateRaw: date,
        timeRaw: eventDetails.time,
      );
    }
    if (isEventPastApi != null) return isEventPastApi!;
    return EventDateUtils.isEventPastFromDateTime(createdAt);
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ??
        json['postId']?.toString() ??
        json['id']?.toString() ??
        '';

    final authorRaw = json['authorId'] ?? json['author'];
    final author = authorRaw is Map<String, dynamic>
        ? FeedPostAuthor.fromJson(authorRaw)
        : authorRaw is Map
            ? FeedPostAuthor.fromJson(Map<String, dynamic>.from(authorRaw))
            : FeedPostAuthor.fromJson(null);

    final detailsRaw = json['eventDetails'];
    final details = detailsRaw is Map<String, dynamic>
        ? FeedEventDetails.fromJson(detailsRaw)
        : detailsRaw is Map
            ? FeedEventDetails.fromJson(Map<String, dynamic>.from(detailsRaw))
            : const FeedEventDetails();

    final createdRaw = json['createdAt'];
    DateTime createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final inCalendar = json['inCalendar'] == true;
    final calendarCountRaw = json['calendarCount'];
    final calendarCount = calendarCountRaw is num
        ? calendarCountRaw.toInt()
        : (inCalendar ? 1 : 0);

    return FeedPost(
      id: id,
      author: author,
      location: json['location'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      liked: json['liked'] as bool? ?? false,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      calendarCount: calendarCount,
      inCalendar: inCalendar,
      calendarStatus: json['calendarStatus'] as String?,
      status: json['status'] as String?,
      eventDetails: details,
      createdAt: createdAt,
      isEventPastApi: json['isEventPast'] is bool ? json['isEventPast'] as bool : null,
      editedAt: _parseEditedAt(json['editedAt']),
      usesDefaultCover: json['usesDefaultCover'] as bool? ?? false,
      coverAspectRatio: parseCoverAspectRatio(json['coverAspectRatio']),
    );
  }

  static DateTime? _parseEditedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  FeedPost copyWith({
    bool? liked,
    int? likesCount,
    int? commentsCount,
    int? calendarCount,
    bool? inCalendar,
    String? calendarStatus,
    bool clearCalendarStatus = false,
  }) {
    return FeedPost(
      id: id,
      author: author,
      location: location,
      imageUrl: imageUrl,
      caption: caption,
      liked: liked ?? this.liked,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      calendarCount: calendarCount ?? this.calendarCount,
      inCalendar: inCalendar ?? this.inCalendar,
      calendarStatus:
          clearCalendarStatus ? null : (calendarStatus ?? this.calendarStatus),
      status: status,
      eventDetails: eventDetails,
      createdAt: createdAt,
      isEventPastApi: isEventPastApi,
      editedAt: editedAt,
      usesDefaultCover: usesDefaultCover,
      coverAspectRatio: coverAspectRatio,
    );
  }

  /// For callers that still expect a map (explore sheet / notification payload).
  Map<String, dynamic> toJson() => {
        '_id': id,
        'postId': id,
        'location': location,
        'imageUrl': imageUrl,
        'caption': caption,
        'liked': liked,
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'calendarCount': calendarCount,
        'inCalendar': inCalendar,
        if (calendarStatus != null) 'calendarStatus': calendarStatus,
        if (status != null) 'status': status,
        if (isEventPastApi != null) 'isEventPast': isEventPastApi,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        'usesDefaultCover': usesDefaultCover,
        if (coverAspectRatio != null) 'coverAspectRatio': coverAspectRatio,
        'createdAt': createdAt.toIso8601String(),
        'authorId': {
          '_id': author.id,
          'id': author.id,
          'username': author.username,
          'displayName': author.displayName,
          'avatarUrl': author.avatarUrl,
          if (author.badge != null) 'badge': author.badge,
        },
        'eventDetails': {
          if (eventDetails.date != null) 'date': eventDetails.date,
          if (eventDetails.time != null) 'time': eventDetails.time,
          if (eventDetails.venue != null) 'venue': eventDetails.venue,
          if (eventDetails.ticketUrl != null) 'ticketUrl': eventDetails.ticketUrl,
          if (!eventDetails.eventLocation.isEmpty)
            'eventLocation': {
              'formattedAddress': eventDetails.eventLocation.formattedAddress,
              if (eventDetails.eventLocation.placeId.isNotEmpty)
                'placeId': eventDetails.eventLocation.placeId,
              if (eventDetails.eventLocation.name.isNotEmpty)
                'name': eventDetails.eventLocation.name,
            },
        },
      };
}
