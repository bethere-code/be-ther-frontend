import 'package:dio/dio.dart';

import '../domain/explore_event.dart';

class ExploreRepository {
  ExploreRepository(this._dio);

  final Dio _dio;

  Future<List<ExploreEvent>> fetchEvents({int skip = 0}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/explore/events',
        queryParameters: {'skip': skip},
      );
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to load explore');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid explore response');
      }
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ExploreEvent.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error']?.toString();
        if (message != null && message.isNotEmpty) throw Exception(message);
      }
      throw Exception(e.message ?? 'Failed to load explore');
    }
  }

  Future<bool> toggleBookmark(String eventId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/explore/events/$eventId/bookmark',
      );
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(
          body?['error']?.toString() ?? 'Failed to update wishlist',
        );
      }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data['bookmarked'] as bool? ?? false;
      }
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final message = err['message']?.toString();
          if (message != null && message.isNotEmpty) throw Exception(message);
        }
      }
      throw Exception(e.message ?? 'Failed to update wishlist');
    }
  }
}
