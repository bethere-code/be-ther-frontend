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

  Future<void> patchMe(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>('/api/v1/users/me', data: payload);
      if (res.data == null || res.data!['ok'] != true) {
        throw Exception(res.data?['error']?.toString() ?? 'Update failed');
      }
    } on DioException catch (e) {
      throw Exception(_errorFromDio(e, fallback: 'Update failed'));
    }
  }

  Future<bool> starToggle(String username) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/users/$username/star');
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to update follow');
      }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data['starred'] as bool? ?? false;
      }
      return false;
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
