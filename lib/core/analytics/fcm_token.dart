import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Reads the current FCM registration token (null if Messaging unavailable).
Future<String?> currentFcmToken() async {
  if (kIsWeb) return null;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.trim().isNotEmpty) return token.trim();
  } catch (_) {
    return null;
  }
  return null;
}

/// FCM topic for a city name (`city_hyderabad`).
String? cityTopicFromName(String? city) {
  final raw = (city ?? '').trim().toLowerCase();
  if (raw.isEmpty) return null;
  final slug = raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.length < 2) return null;
  return 'city_${slug.length > 80 ? slug.substring(0, 80) : slug}';
}

const broadcastTopic = 'broadcast';
