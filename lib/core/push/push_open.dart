import '../../features/event/presentation/shared_event_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

const _postKinds = {'like', 'comment', 'wishlist', 'calendar'};
const _followKinds = {
  'follow',
  'star',
  'follow_request',
  'follow_request_accepted',
  'follow_request_accepted_owner',
  'follow_request_rejected_owner',
};

/// Maps admin FCM `screen` + `id` or social `kind` to an in-app route.
/// Null = stay put (sync only).
String? locationFromPushData(Map<String, dynamic> data) {
  final screen = data['screen']?.toString() ?? '';
  final id = data['id']?.toString().trim() ?? '';
  if (screen.isNotEmpty) {
    switch (screen) {
      case 'alerts':
        return NotificationsScreen.path;
      case 'settings':
        return SettingsScreen.path;
      case 'profile':
        if (id.isEmpty) return null;
        return ProfileScreen.pathForUser(id);
      case 'event':
        if (id.isEmpty) return null;
        return SharedEventScreen.pathFor(id);
    }
  }

  final kind = data['kind']?.toString() ?? '';
  final postId = data['postId']?.toString().trim() ?? '';
  final username = data['username']?.toString().trim() ?? '';

  if (_postKinds.contains(kind) && postId.isNotEmpty) {
    return SharedEventScreen.pathFor(postId);
  }
  if (_followKinds.contains(kind) && username.isNotEmpty) {
    return ProfileScreen.pathForUser(username);
  }
  return null;
}
