import 'package:dio/dio.dart';

class UserRepository {
  UserRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> me() async {
    return _getData('/api/v1/users/me', fallback: 'Failed to load profile');
  }

  Future<Map<String, dynamic>> byUsername(String username) async {
    return _getData('/api/v1/users/$username', fallback: 'Failed to load user');
  }

  Future<List<Map<String, dynamic>>> calendar(String username) async {
    final data = await _getData('/api/v1/users/$username/calendar', fallback: 'Failed to load calendar');
    return (data['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> patchMe(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>('/api/v1/users/me', data: payload);
      if (res.data == null || res.data!['ok'] != true) {
        throw Exception(res.data?['error']?.toString() ?? 'Update failed');
      }
      final data = res.data!['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Update failed');
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: 'Update failed'));
    }
  }

  Future<String> uploadImage(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/media/upload',
        data: form,
      );
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Upload failed');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Upload failed');
      }
      final url = data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Upload returned empty URL');
      }
      return url;
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: 'Upload failed'));
    }
  }

  /// Persists OS notification/location permission state on the user profile for stats.
  Future<void> syncDevicePermissions({
    required String notification,
    required String location,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/users/me/device-permissions',
        data: {
          'notification': notification,
          'location': location,
        },
      );
      if (res.data == null || res.data!['ok'] != true) {
        throw Exception(res.data?['error']?.toString() ?? 'Failed to sync permissions');
      }
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: 'Failed to sync permissions'));
    }
  }

  /// Toggle follow. Returns whether you now follow them + their follower count.
  Future<({bool following, int followersCount})> toggleFollow(String username) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/users/$username/follow');
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to update follow');
      }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return (
          following: data['following'] as bool? ?? false,
          followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
        );
      }
      return (following: false, followersCount: 0);
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: 'Failed to update follow'));
    }
  }

  Future<Map<String, dynamic>> _getData(String path, {required String fallback}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      final body = res.data;
      if (body == null || body['ok'] != true) throw Exception(body?['error']?.toString() ?? fallback);
      final data = body['data'];
      if (data is! Map<String, dynamic>) throw Exception(fallback);
      return data;
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: fallback));
    }
  }

  String _errorFromDio(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return e.message ?? fallback;
  }
}
