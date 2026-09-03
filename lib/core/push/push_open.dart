import '../../features/event/presentation/shared_event_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Maps admin FCM `screen` + `id` to an in-app route. Null = stay put (sync only).
String? locationFromPushData(Map<String, dynamic> data) {
  final screen = data['screen']?.toString() ?? '';
  final id = data['id']?.toString().trim() ?? '';
  switch (screen) {
    case 'alerts':
      return NotificationsScreen.path;
    case 'settings':
      return SettingsScreen.path;
    case 'profile':
      if (id.isEmpty) return null;
      return '${ProfileScreen.path}/$id';
    case 'event':
      if (id.isEmpty) return null;
      return SharedEventScreen.pathFor(id);
    default:
      return null;
  }
}
