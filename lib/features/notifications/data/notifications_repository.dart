import 'package:dio/dio.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/notifications');
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to load notifications');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) throw Exception('Invalid notifications response');
      return (data['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error']?.toString();
        if (message != null && message.isNotEmpty) throw Exception(message);
      }
      throw Exception(e.message ?? 'Failed to load notifications');
    }
  }

  Future<void> markRead(String id) async {
    await _dio.patch<Map<String, dynamic>>('/api/v1/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _dio.patch<Map<String, dynamic>>('/api/v1/notifications/read-all');
  }

  Future<({bool accepted, int followersCount})> respondFollowRequest({
    required String username,
    required String action,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users/$username/follow-request',
        data: {'action': action},
      );
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(
          body?['error']?.toString() ?? 'Failed to update follow request',
        );
      }
      final data = body['data'];
      if (data is Map) {
        return (
          accepted: data['accepted'] == true,
          followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
        );
      }
      return (accepted: false, followersCount: 0);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map && err['message'] != null) {
          throw Exception(err['message'].toString());
        }
      }
      throw Exception(e.message ?? 'Failed to update follow request');
    }
  }

  Future<int> unreadCount() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/notifications/unread-count');
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to load unread count');
      }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data['count'] as int? ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final message = err['message']?.toString();
          if (message != null && message.isNotEmpty) throw Exception(message);
        }
      }
      throw Exception(e.message ?? 'Failed to load unread count');
    }
  }
}
