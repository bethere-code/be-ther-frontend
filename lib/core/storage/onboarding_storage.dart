import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingStorage {
  OnboardingStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _seenKey = 'onboarding_seen_v1';

  final FlutterSecureStorage _storage;

  Future<bool> hasSeenOnboarding() async {
    final value = await _storage.read(key: _seenKey);
    return value == 'true';
  }

  Future<void> markSeen() async {
    await _storage.write(key: _seenKey, value: 'true');
  }
}
