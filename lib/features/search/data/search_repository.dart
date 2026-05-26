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
      final response = await _dio.get(
        '/api/v1/posts/search',
        queryParameters: {
          'query': query,
          if (country != null && country.isNotEmpty) 'country': country,
          'skip': skip,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final nextSkip = data['nextSkip'] as int?;

      return SearchResult(items: items, nextSkip: nextSkip);
    } on DioException {
      rethrow;
    }
  }
}
