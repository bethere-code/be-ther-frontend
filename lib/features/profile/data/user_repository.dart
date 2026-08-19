import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

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

  Future<List<Map<String, dynamic>>> events(String username) async {
    final data = await _getData(
      '/api/v1/users/$username/events',
      fallback: 'Failed to load events',
    );
    return (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> followers(String username) async {
    final data = await _getData(
      '/api/v1/users/$username/followers',
      fallback: 'Failed to load followers',
    );
    return (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> following(String username) async {
    final data = await _getData(
      '/api/v1/users/$username/following',
      fallback: 'Failed to load following',
    );
    return (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> patchMe(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>('/api/v1/users/me', data: payload);
      if (res.data == null || res.data!['ok'] != true) {
        throw ApiException(
          _messageFromBody(res.data, 'Update failed'),
          statusCode: res.statusCode,
        );
      }
      final data = res.data!['data'];
      if (data is! Map<String, dynamic>) {
        throw ApiException('Update failed', statusCode: res.statusCode);
      }
      return data;
    } on DioException catch (e) {
      throw ApiException(
        _errorFromDio(e, fallback: 'Update failed'),
        statusCode: e.response?.statusCode,
      );
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
        throw ApiException(
          _messageFromBody(body, 'Upload failed'),
          statusCode: res.statusCode,
        );
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
      throw ApiException(
        _errorFromDio(e, fallback: 'Upload failed'),
        statusCode: e.response?.statusCode,
      );
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
        throw ApiException(
          _messageFromBody(res.data, 'Failed to sync permissions'),
          statusCode: res.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException(
        _errorFromDio(e, fallback: 'Failed to sync permissions'),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Toggle follow. Returns whether you now follow them + their follower count.
  Future<({bool following, int followersCount})> toggleFollow(String username) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/users/$username/follow');
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw ApiException(
          _messageFromBody(body, 'Failed to update follow'),
          statusCode: res.statusCode,
        );
      }
      final data = body['data'];
      if (data is Map) {
        return (
          following: data['following'] == true,
          followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
        );
      }
      return (following: false, followersCount: 0);
    } on DioException catch (e) {
      throw ApiException(
        _errorFromDio(e, fallback: 'Failed to update follow'),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _getData(String path, {required String fallback}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw ApiException(
          _messageFromBody(body, fallback),
          statusCode: res.statusCode,
        );
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw ApiException(fallback, statusCode: res.statusCode);
      }
      return data;
    } on DioException catch (e) {
      throw ApiException(
        _errorFromDio(e, fallback: fallback),
        statusCode: e.response?.statusCode,
      );
    }
  }

  String _errorFromDio(DioException e, {required String fallback}) {
    return _messageFromBody(e.response?.data, e.message ?? fallback);
  }

  String _messageFromBody(dynamic body, String fallback) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map && error['message'] != null) {
        final message = error['message'].toString().trim();
        if (message.isNotEmpty) return message;
      }
      if (error is String && error.trim().isNotEmpty) return error.trim();
    }
    return fallback;
  }
}
