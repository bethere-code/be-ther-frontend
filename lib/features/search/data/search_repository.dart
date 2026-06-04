import 'package:dio/dio.dart';

class SearchResult {
  final List<Map<String, dynamic>> items;
  final int? nextSkip;

  SearchResult({required this.items, this.nextSkip});
}

class SearchRepository {
  final Dio _dio;

  SearchRepository(this._dio);

  Future<SearchResult> search({
    required String query,
    String? country,
    int skip = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/posts/search',
        queryParameters: {
          'query': query,
          if (country != null && country.isNotEmpty) 'country': country,
          'skip': skip,
        },
      );

      final body = response.data;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error']?.toString() ?? 'Search failed');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid search response');
      }
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');

      return SearchResult(items: items, nextSkip: nextSkip);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final message = err['message']?.toString();
          if (message != null && message.isNotEmpty) throw Exception(message);
        }
      }
      throw Exception(e.message ?? 'Search failed');
    }
  }
}
