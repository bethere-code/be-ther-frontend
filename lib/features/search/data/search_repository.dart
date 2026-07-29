import 'package:dio/dio.dart';

import '../domain/search_post.dart';

class SearchRepository {
  SearchRepository(this._dio);

  final Dio _dio;

  Future<SearchPage> search({
    required String query,
    String? country,
    int skip = 0,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return SearchPage.empty();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/posts/search',
        queryParameters: {
          'query': trimmed,
          if (country != null && country.isNotEmpty) 'country': country,
          'skip': skip,
        },
        cancelToken: cancelToken,
      );

      final body = response.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Search failed');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid search response');
      }
      return SearchPage.fromJson(data);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final message = err['message']?.toString();
          if (message != null && message.isNotEmpty) throw Exception(message);
        }
        final message = data['error']?.toString();
        if (message != null && message.isNotEmpty) throw Exception(message);
      }
      throw Exception(e.message ?? 'Search failed');
    }
  }
}
