/// Converts incoming app / web links into in-app routes.
String? eventRouteFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (segments.length >= 2 && segments.first == 'e') {
      return '/event/${segments[1]}';
    }
    return null;
  }

  if (uri.scheme != 'bether') return null;

  if (uri.host == 'e' && segments.isNotEmpty) {
    return '/event/${segments.first}';
  }

  if (segments.length >= 2 && segments.first == 'e') {
    return '/event/${segments[1]}';
  }

  return null;
}
