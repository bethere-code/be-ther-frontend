import 'package:dio/dio.dart';

class ExploreRepository {
  ExploreRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchEvents(String type) async {
    try {
      final normalizedType = switch (type) {
        'events' || 'places' || 'all' => type,
        _ => 'all',
      };
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/explore/events',
        queryParameters: {'type': normalizedType},
      );
      final body = res.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Failed to load explore');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) throw Exception('Invalid explore response');
      return (data['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error']?.toString();
        if (message != null && message.isNotEmpty) throw Exception(message);
      }
      throw Exception(e.message ?? 'Failed to load explore');
    }
  }
}
