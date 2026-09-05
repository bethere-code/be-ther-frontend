import '../../explore/domain/explore_event.dart';
import 'feed_post.dart';

/// Session overlay for edited events — keeps feed / explore / profile in sync
/// until the next API refresh.
FeedPost buildEditedFeedPost({
  required FeedPost base,
  required String location,
  required String caption,
  required String imageUrl,
  required bool usesDefaultCover,
  double? coverAspectRatio,
  required String status,
  required StructuredPlaceFields place,
  String? date,
  String? time,
  String? ticketUrl,
  DateTime? editedAt,
}) {
  final eventLocation = FeedEventPlace(
    placeId: place.placeId,
    name: place.name,
    formattedAddress: place.formattedAddress,
    lat: place.lat,
    lng: place.lng,
  );
  final calendarStatus = status == 'interested' ? 'interested' : 'going';
  return FeedPost(
    id: base.id,
    author: base.author,
    location: location,
    imageUrl: imageUrl,
    caption: caption,
    liked: base.liked,
    likesCount: base.likesCount,
    commentsCount: base.commentsCount,
    calendarCount: base.calendarCount,
    inCalendar: base.inCalendar,
    calendarStatus: calendarStatus,
    status: status,
    eventDetails: FeedEventDetails(
      date: date,
      time: time,
      venue: place.name,
      ticketUrl: ticketUrl,
      eventLocation: eventLocation,
    ),
    createdAt: base.createdAt,
    isEventPastApi: base.isEventPastApi,
    editedAt: editedAt ?? DateTime.now(),
    usesDefaultCover: usesDefaultCover,
    coverAspectRatio: coverAspectRatio,
  );
}

/// Minimal place fields for building an edited post without importing the widget.
class StructuredPlaceFields {
  const StructuredPlaceFields({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  final String placeId;
  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
}

FeedPost overlayEditedFeedPost(FeedPost post, Map<String, FeedPost> edits) {
  final id = post.id.trim();
  if (id.isEmpty) return post;
  return edits[id] ?? post;
}

ExploreEvent overlayEditedExploreEvent(
  ExploreEvent event,
  Map<String, FeedPost> edits,
) {
  final edit = edits[event.id];
  if (edit == null) return event;
  final details = edit.eventDetails;
  final loc = details.eventLocation;
  final dateRaw = details.date?.trim();
  final isPast = dateRaw != null && dateRaw.isNotEmpty
      ? edit.isPast
      : event.isPast;
  return ExploreEvent(
    id: event.id,
    title: edit.location,
    imageUrl: edit.imageUrl,
    place: loc.name.isNotEmpty ? loc.name : event.place,
    address: loc.formattedAddress.isNotEmpty
        ? loc.formattedAddress
        : event.address,
    country: event.country,
    venue: (details.venue?.trim().isNotEmpty == true)
        ? details.venue!.trim()
        : (loc.name.isNotEmpty ? loc.name : event.venue),
    dateRaw: dateRaw ?? event.dateRaw,
    time: details.time ?? event.time,
    ticketUrl: details.ticketUrl ?? event.ticketUrl,
    caption: edit.caption.isNotEmpty ? edit.caption : event.caption,
    attendees: event.attendees,
    trending: event.trending,
    status: edit.status ?? event.status,
    author: event.author,
    authorUserId: event.authorUserId,
    liked: event.liked,
    bookmarked: event.bookmarked,
    inCalendar: event.inCalendar,
    calendarStatus: edit.calendarStatus ?? event.calendarStatus,
    isPast: isPast,
    likesCount: event.likesCount,
    commentsCount: event.commentsCount,
    editedAt: edit.editedAt ?? DateTime.now(),
    usesDefaultCover: edit.usesDefaultCover,
    coverAspectRatio: edit.coverAspectRatio ?? event.coverAspectRatio,
  );
}

List<FeedPost> overlayEditedFeedPosts(
  Iterable<FeedPost> posts,
  Map<String, FeedPost> edits,
) {
  if (edits.isEmpty) return posts is List<FeedPost> ? posts : posts.toList();
  return [
    for (final post in posts) overlayEditedFeedPost(post, edits),
  ];
}

List<ExploreEvent> overlayEditedExploreEvents(
  Iterable<ExploreEvent> events,
  Map<String, FeedPost> edits,
) {
  if (edits.isEmpty) {
    return events is List<ExploreEvent> ? events : events.toList();
  }
  return [
    for (final event in events) overlayEditedExploreEvent(event, edits),
  ];
}
