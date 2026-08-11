/// Converts incoming app / web links into in-app routes.
///
/// Public share links are `https://be-ther.com/e/:postId` (and `bether://e/:postId`).
/// In-app destination matches that path so Flutter/GoRouter deep links resolve.
String? eventRouteFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final scheme = uri.scheme.toLowerCase();

  // Full https/http share URLs, or path-only `/e/:id` from the platform router.
  if (scheme == 'https' ||
      scheme == 'http' ||
      scheme.isEmpty ||
      scheme == 'file') {
    if (segments.length >= 2 && segments.first == 'e') {
      return SharedEventPaths.pathFor(segments[1]);
    }
    // Legacy in-app path kept for pending links / older builds.
    if (segments.length >= 2 && segments.first == 'event') {
      return SharedEventPaths.pathFor(segments[1]);
    }
    return null;
  }

  if (scheme != 'bether') return null;

  if (uri.host == 'e' && segments.isNotEmpty) {
    return SharedEventPaths.pathFor(segments.first);
  }

  if (segments.length >= 2 && segments.first == 'e') {
    return SharedEventPaths.pathFor(segments[1]);
  }

  return null;
}

/// Canonical shared-event paths (must match [SharedEventScreen] + share URLs).
abstract final class SharedEventPaths {
  static const path = '/e/:postId';
  static String pathFor(String id) => '/e/$id';

  static bool isEventLocation(String location) {
    return location.startsWith('/e/') || location.startsWith('/event/');
  }
}
