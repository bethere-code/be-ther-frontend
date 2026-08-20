import 'package:dio/dio.dart';

import '../domain/comment.dart';
import '../domain/feed_post.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

  Future<FeedPage> fetchFeed({int skip = 0}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/posts/feed', queryParameters: {'skip': skip});
      final data = _extractData(res.data, fallbackMessage: 'Failed to load feed');
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => FeedPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int ? nextSkipRaw : int.tryParse('$nextSkipRaw');
      return FeedPage(items: items, nextSkip: nextSkip);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load feed'));
    }
  }

  Future<FeedPost> fetchPost(String postId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/posts/$postId');
      final data = _extractData(res.data, fallbackMessage: 'Failed to load event');
      final post = data['post'];
      if (post is! Map) {
        throw Exception('Failed to load event');
      }
      return FeedPost.fromJson(Map<String, dynamic>.from(post));
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load event'));
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

  Future<void> hideOnProfile(String postId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/hide-on-profile');
      _extractData(res.data, fallbackMessage: 'Failed to hide event');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to hide event'));
    }
  }

  Future<void> unhideOnProfile(String postId) async {
    try {
      // Prefer DELETE on the same hide resource; fall back to POST unhide.
      try {
        final res = await _dio.delete<Map<String, dynamic>>(
          '/api/v1/posts/$postId/hide-on-profile',
        );
        _extractData(res.data, fallbackMessage: 'Failed to show event');
        return;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code != 404 && code != 405) rethrow;
      }
      final res =
          await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/unhide-on-profile');
      _extractData(res.data, fallbackMessage: 'Failed to show event');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        throw Exception(
          'Show on profile needs a server update. Redeploy the backend, then try again.',
        );
      }
      throw Exception(_apiMessage(e, fallback: 'Failed to show event'));
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/api/v1/posts/$postId');
      _extractData(res.data, fallbackMessage: 'Failed to delete event');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to delete event'));
    }
  }

  Future<void> markNotGoing(String postId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/not-going');
      _extractData(res.data, fallbackMessage: 'Failed to update event');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to update event'));
    }
  }

  Future<void> submitReport({
    required String postId,
    required String type,
    String details = '',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/posts/$postId/reports',
        data: {
          'type': type,
          if (details.isNotEmpty) 'details': details,
        },
      );
      _extractData(res.data, fallbackMessage: 'Failed to submit report');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to submit report'));
    }
  }

  Future<Map<String, dynamic>> setCalendarStatus({
    required String postId,
    required String status,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/posts/$postId/calendar',
        data: {'status': status},
      );
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) return data;
      return {
        'inCalendar': status != 'none',
        'calendarStatus': status == 'none' ? null : status,
      };
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to update calendar'));
    }
  }

  /// Legacy toggle — prefer [setCalendarStatus] with an explicit RSVP.
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

  /// Best-effort unique view. Prefer [EventViewRecorder] so this stays off the hot path.
  Future<void> recordView(String postId) async {
    if (postId.isEmpty) return;
    await _dio.post<Map<String, dynamic>>('/api/v1/posts/$postId/view');
  }

  Future<AttendeesPage> fetchAttendees({
    required String postId,
    int skip = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/posts/$postId/attendees',
        queryParameters: {'skip': skip},
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Failed to load attendees',
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int
          ? nextSkipRaw
          : int.tryParse('$nextSkipRaw');
      return AttendeesPage(items: items, total: total, nextSkip: nextSkip);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load attendees'));
    }
  }

  Future<LikesPage> fetchLikes({
    required String postId,
    int skip = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/posts/$postId/likes',
        queryParameters: {'skip': skip},
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Failed to load likes',
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int
          ? nextSkipRaw
          : int.tryParse('$nextSkipRaw');
      return LikesPage(items: items, total: total, nextSkip: nextSkip);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load likes'));
    }
  }

  Future<CommentsPage> fetchComments({
    required String postId,
    int skip = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/posts/$postId/comments',
        queryParameters: {'skip': skip},
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Failed to load comments',
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Comment.fromJson)
          .toList(growable: false);
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      final nextSkipRaw = data['nextSkip'];
      final nextSkip = nextSkipRaw is int
          ? nextSkipRaw
          : int.tryParse('$nextSkipRaw');
      return CommentsPage(items: items, total: total, nextSkip: nextSkip);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to load comments'));
    }
  }

  Future<Comment> createComment({
    required String postId,
    required String text,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/posts/$postId/comments',
        data: {'text': text},
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Failed to post comment',
      );
      return Comment.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to post comment'));
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/api/v1/comments/$commentId',
      );
      _extractData(res.data, fallbackMessage: 'Failed to delete comment');
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to delete comment'));
    }
  }

  Future<({bool liked, int likesCount})> toggleCommentLike(
    String commentId,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/comments/$commentId/like',
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Failed to update like',
      );
      return (
        liked: data['liked'] as bool? ?? false,
        likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Failed to update like'));
    }
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/posts', data: payload);
      final data = _extractData(res.data, fallbackMessage: 'Failed to create post');
      final id = _readPostId(data);
      if (id.isEmpty) {
        throw const FormatException('Create post returned empty id');
      }
      return {
        ...data,
        '_id': id,
        'postId': id,
      };
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

  /// Server-side OG preview for external ticket links (BookMyShow, etc.).
  Future<String?> fetchLinkPreviewImageUrl(String pageUrl) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/link-preview',
        queryParameters: {'url': pageUrl},
      );
      final data = _extractData(
        res.data,
        fallbackMessage: 'Could not load link preview',
      );
      final imageUrl = data['imageUrl']?.toString().trim();
      if (imageUrl == null || imageUrl.isEmpty) return null;
      return imageUrl;
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, fallback: 'Could not load link preview'));
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
    final status = e.response?.statusCode;
    if (status == 413) {
      return 'Photo is too large. Please choose a smaller image (under 8 MB).';
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
      // Fastify default 404: { error: "Not Found", message: "Route GET:..." }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty && message.startsWith('Route ')) {
        return 'Not Found';
      }
      final flat = error?.toString();
      if (flat != null && flat.isNotEmpty && flat != 'null') return flat;
    }

    final dioMessage = e.message ?? '';
    if (dioMessage.contains('validateStatus') ||
        dioMessage.contains('status code of') ||
        dioMessage.contains('DioException')) {
      return fallback;
    }
    if (dioMessage.isNotEmpty) return dioMessage;
    return fallback;
  }
}

class FeedPage {
  FeedPage({required this.items, required this.nextSkip});

  final List<FeedPost> items;
  final int? nextSkip;
}

class AttendeesPage {
  AttendeesPage({
    required this.items,
    required this.total,
    this.nextSkip,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int? nextSkip;
}
