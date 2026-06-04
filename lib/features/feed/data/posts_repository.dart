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

  Future<bool> toggleLike(String postId) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/like');
    final data = res.data?['data'];
    if (data is Map<String, dynamic>) {
      return data['liked'] as bool? ?? false;
    }
    return false;
  }

  Future<bool> toggleBookmark(String postId) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/bookmark');
    final data = res.data?['data'];
    if (data is Map<String, dynamic>) {
      return data['bookmarked'] as bool? ?? false;
    }
    return false;
  }

  Future<bool> toggleCalendar(String postId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/calendar');
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        return data['inCalendar'] as bool? ?? false;
      }
      return false;
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to update calendar'));
    }
  }

  Future<String> createPost(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts', data: payload);
      final data = _extractData(res.data, fallbackMessage: 'Failed to create post');
      final id = _readPostId(data);
      if (id.isEmpty) {
        throw const FormatException('Create post returned empty id');
      }
      return id;
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to create post'));
    }
  }

  String _readPostId(Map<String, dynamic> data) {
    final raw = data['postId'] ?? data['id'] ?? data['_id'];
    if (raw is String) return raw;
    if (raw is Map) {
      final oid = raw[r'$oid'] ?? raw['oid'];
      if (oid is String) return oid;
    }
    return raw?.toString() ?? '';
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

  String apiMessage(DioException e, {required String fallback}) {
    return _apiMessage(e, fallback: fallback);
  }

  String _apiMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
      final flat = error?.toString();
      if (flat != null && flat.isNotEmpty && flat != 'null') return flat;
    }
    return e.message ?? fallback;
  }
}

class FeedPage {
  FeedPage({required this.items, required this.nextSkip});

  final List<Map<String, dynamic>> items;
  final int? nextSkip;
}
