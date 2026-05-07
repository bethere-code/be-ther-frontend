import 'package:dio/dio.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

  Future<FeedPage> fetchFeed({int skip = 0}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/posts/feed', queryParameters: {'skip': skip});
      final data = _extractData(res.data, fallbackMessage: 'Failed to load feed');
      final items = (data['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');
      return FeedPage(items: items, nextSkip: nextSkip);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load feed'));
    }
  }

  Future<void> toggleLike(String postId) async {
    await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/like');
  }

  Future<void> toggleBookmark(String postId) async {
    await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/bookmark');
  }

  Future<void> createPost(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts', data: payload);
      _extractData(res.data, fallbackMessage: 'Failed to create post');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to create post'));
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
      final data = _extractData(res.data, fallbackMessage: 'Upload failed');
      final url = data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const FormatException('Upload returned empty URL');
      }
      return url;
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Upload failed'));
    }
  }

  Map<String, dynamic> _extractData(
    Map<String, dynamic>? body, {
    required String fallbackMessage,
  }) {
    if (body == null || body['ok'] != true) {
      throw Exception(body?['error']?.toString() ?? fallbackMessage);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception(fallbackMessage);
    }
    return data;
  }

  String _apiMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error']?.toString();
      if (error != null && error.isNotEmpty) return error;
    }
    return e.message ?? fallback;
  }
}

class FeedPage {
  FeedPage({required this.items, required this.nextSkip});

  final List<Map<String, dynamic>> items;
  final int? nextSkip;
}
