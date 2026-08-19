import 'package:dio/dio.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._dio);

  final Dio _dio;

  Future<({List<String> acked, List<String> duplicates})> sendBatch({
    required List<Map<String, dynamic>> events,
    required String trigger,
    Map<String, dynamic>? app,
  }) async {
    final body = <String, dynamic>{
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'trigger': trigger,
      'events': events,
    };
    if (app != null) body['app'] = app;
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/analytics/events',
      data: body,
    );
    final data = res.data?['data'];
    if (data is! Map) {
      return (acked: const <String>[], duplicates: const <String>[]);
    }
    List<String> ids(dynamic v) =>
        (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    return (
      acked: ids(data['acknowledgedEventIds']),
      duplicates: ids(data['duplicateEventIds']),
    );
  }
}
