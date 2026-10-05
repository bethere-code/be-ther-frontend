import 'push_open.dart';

void main() {
  assert(
    locationFromPushData({'screen': 'event', 'id': 'abc'}) == '/e/abc',
  );
  assert(
    locationFromPushData({'kind': 'like', 'postId': 'abc'}) == '/e/abc',
  );
  assert(
    locationFromPushData({'kind': 'comment', 'postId': 'abc'}) == '/e/abc',
  );
  assert(
    locationFromPushData({'kind': 'follow', 'username': 'alex'}) ==
        '/profile/alex',
  );
  assert(locationFromPushData({'type': 'unread_sync'}) == null);
  // ignore: avoid_print
  print('push_open.check: ok');
}
