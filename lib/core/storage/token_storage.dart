import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccess = 'be_ther_access_token';
const _kRefresh = 'be_ther_refresh_token';
const _kUser = 'be_ther_cached_user';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> write({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<(String?, String?)> read() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    return (access, refresh);
  }

  /// Cached profile so UI keeps a user while tokens refresh /me is offline.
  Future<void> writeUser(Map<String, dynamic> user) async {
    await _storage.write(key: _kUser, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
