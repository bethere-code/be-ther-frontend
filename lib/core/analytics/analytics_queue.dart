import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class QueuedAnalyticsEvent {
  QueuedAnalyticsEvent({
    required this.eventId,
    required this.payload,
    this.retries = 0,
  });

  final String eventId;
  final Map<String, dynamic> payload;
  int retries;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'retries': retries,
        'payload': payload,
      };

  factory QueuedAnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return QueuedAnalyticsEvent(
      eventId: json['eventId'] as String? ?? '',
      retries: (json['retries'] as num?)?.toInt() ?? 0,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : {},
    );
  }
}

String newAnalyticsEventId() {
  final n = Random().nextInt(1 << 32);
  return '${DateTime.now().microsecondsSinceEpoch}-$n';
}

class AnalyticsQueue {
  static const _fileName = 'analytics_queue.json';
  static const maxRetries = 5;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<QueuedAnalyticsEvent>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => QueuedAnalyticsEvent.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.eventId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<QueuedAnalyticsEvent> items) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<String> enqueue(Map<String, dynamic> payload) async {
    final items = await load();
    final id = payload['eventId'] as String? ?? newAnalyticsEventId();
    payload['eventId'] = id;
    items.add(QueuedAnalyticsEvent(eventId: id, payload: payload));
    await save(items);
    return id;
  }
}
