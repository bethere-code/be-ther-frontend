import 'package:flutter/services.dart';

/// Reads FCM when Firebase Messaging is registered. Returns null until
/// `google-services.json` / `GoogleService-Info.plist` and the plugin exist.
Future<String?> currentFcmToken() async {
  try {
    const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
    final token = await channel.invokeMethod<String>('Messaging#getToken');
    if (token != null && token.trim().isNotEmpty) return token.trim();
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
  return null;
}
