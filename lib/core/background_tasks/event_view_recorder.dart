import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Low-priority, session-deduped event view recorder.
///
/// Rules:
/// - Feed: enqueue when a card is meaningfully visible (no details sheet).
/// - Explore / search: enqueue only when the event details sheet opens.
/// - Same [postId] is never sent twice in one app session across any screen.
/// - Flushes on [Priority.idle] after a settle delay so scroll/search APIs
///   are not starved; queue drains serially with gaps (no polling).
final eventViewRecorderProvider = Provider<EventViewRecorder>((ref) {
  final recorder = EventViewRecorder(ref.watch(apiClientProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});

class EventViewRecorder {
  EventViewRecorder(this._dio);

  final Dio _dio;

  /// Post IDs already queued or sent this session (cross-screen dedupe).
  final Set<String> _sessionSeen = <String>{};
  final Queue<String> _pending = Queue<String>();

  bool _draining = false;
  bool _disposed = false;
  Timer? _settleTimer;

  /// Initial delay before the first idle flush — lets urgent APIs go first.
  static const Duration _settleDelay = Duration(milliseconds: 1200);

  /// Gap between queued view posts so we never burst.
  static const Duration _betweenViews = Duration(milliseconds: 450);

  /// Whether this post was already counted/queued this session.
  bool hasSeen(String postId) => _sessionSeen.contains(postId.trim());

  /// Enqueue a view for [postId]. No-op if already seen. Never awaits.
  void enqueue(String postId) {
    if (_disposed) return;
    final id = postId.trim();
    if (id.isEmpty || _sessionSeen.contains(id)) return;

    _sessionSeen.add(id);
    _pending.add(id);
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_disposed || _draining) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () {
      if (_disposed) return;
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          unawaited(_drain());
        },
        Priority.idle,
      );
    });
  }

  Future<void> _drain() async {
    if (_disposed || _draining) return;
    _draining = true;
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final id = _pending.removeFirst();
        try {
          await _dio.post<Map<String, dynamic>>(
            '/api/v1/posts/$id/view',
            options: Options(
              // Views are best-effort — fail fast, never block the UI.
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );
        } catch (_) {
          // Swallow — sessionSeen already set so we won't spam retries.
        }
        if (_pending.isNotEmpty && !_disposed) {
          await Future<void>.delayed(_betweenViews);
        }
      }
    } finally {
      _draining = false;
      if (!_disposed && _pending.isNotEmpty) {
        _scheduleDrain();
      }
    }
  }

  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _settleTimer = null;
    _pending.clear();
  }
}
