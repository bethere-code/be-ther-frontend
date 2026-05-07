import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccess = 'be_ther_access_token';
const _kRefresh = 'be_ther_refresh_token';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> write({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<(String?, String?)> read() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    return (access, refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
