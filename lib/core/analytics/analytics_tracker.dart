import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../network/api_client.dart';
import 'analytics_queue.dart';
import 'analytics_repository.dart';
import 'device_snapshot.dart';

const _flushEvery = Duration(minutes: 5);
const _flushAtCount = 40;
const _minDurationMs = 1000;
const _maxDurationMs = 30 * 60 * 1000;
const _skipScreens = {'splash'};

class AnalyticsTracker with WidgetsBindingObserver {
  AnalyticsTracker(this._ref);

  final Ref _ref;
  final AnalyticsQueue _queue = AnalyticsQueue();
  Timer? _timer;
  GoRouter? _router;
  bool _running = false;
  bool _flushing = false;

  String? _screen;
  String? _path;
  DateTime? _enteredAt;

  AnalyticsRepository get _repo =>
      AnalyticsRepository(_ref.read(apiClientProvider));

  Future<void> start(GoRouter router) async {
    if (_running) return;
    _running = true;
    _router = router;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_flushEvery, (_) => unawaited(flush(trigger: 'periodic')));
    onRouteChanged();
    unawaited(flush(trigger: 'launch'));
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _closeScreen(exitReason: 'stop');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_closeScreen(exitReason: 'background'));
      unawaited(flush(trigger: 'background'));
    } else if (state == AppLifecycleState.resumed && _running) {
      _onRoute();
    }
  }

  void onRouteChanged() {
    if (!_running) return;
    scheduleMicrotask(_onRoute);
  }

  Future<void> recordAuth(String action) async {
    Map<String, dynamic>? device;
    try {
      device = (await collectDeviceSnapshot()).toJson();
    } catch (_) {
      device = null;
    }
    await _queue.enqueue({
      'eventId': newAnalyticsEventId(),
      'type': 'auth',
      'action': action,
      'at': DateTime.now().toUtc().toIso8601String(),
      if (device != null) 'device': device,
    });
  }

  Future<void> onAuthenticated(String action) async {
    await recordAuth(action);
    await flush(trigger: 'manual');
  }

  Future<void> onLogout() async {
    await _closeScreen(exitReason: 'logout');
    await recordAuth('logout');
    await flush(trigger: 'logout');
    await stop();
  }

  void _onRoute() {
    final router = _router;
    if (router == null) return;
    final cfg = router.routerDelegate.currentConfiguration;
    if (cfg.matches.isEmpty) return;
    String name = '';
    for (final match in cfg.matches.reversed) {
      final route = match.route;
      if (route is GoRoute && (route.name ?? '').isNotEmpty) {
        name = route.name!;
        break;
      }
    }
    if (name.isEmpty || _skipScreens.contains(name)) return;
    final path = _pathTemplate(cfg.uri.path);
    if (name == _screen && path == _path) return;
    unawaited(_swapScreen(name, path));
  }

  Future<void> _swapScreen(String name, String path) async {
    await _closeScreen(exitReason: 'navigate');
    _screen = name;
    _path = path;
    _enteredAt = DateTime.now().toUtc();
  }

  Future<void> _closeScreen({required String exitReason}) async {
    final screen = _screen;
    final entered = _enteredAt;
    final path = _path;
    _screen = null;
    _path = null;
    _enteredAt = null;
    if (screen == null || entered == null) return;
    final exited = DateTime.now().toUtc();
    var duration = exited.difference(entered).inMilliseconds;
    if (duration < _minDurationMs) return;
    if (duration > _maxDurationMs) duration = _maxDurationMs;
    await _queue.enqueue({
      'eventId': newAnalyticsEventId(),
      'type': 'screen_time',
      'screen': screen,
      'path': path ?? '',
      'enteredAt': entered.toIso8601String(),
      'exitedAt': exited.toIso8601String(),
      'durationMs': duration,
      'exitReason': exitReason,
    });
    final items = await _queue.load();
    if (items.length >= _flushAtCount) {
      await flush(trigger: 'manual');
    }
  }

  String _pathTemplate(String path) {
    final parts = path.split('/');
    if (parts.length >= 3 && parts[1] == 'profile' && parts[2].isNotEmpty) {
      parts[2] = ':username';
    }
    return parts.join('/');
  }

  Future<void> flush({required String trigger}) async {
    if (_flushing) return;
    if (!_ref.read(authNotifierProvider).isAuthenticated) return;
    _flushing = true;
    try {
      var items = await _queue.load();
      if (items.isEmpty) return;
      final batch = items.take(50).toList();
      final events = batch.map((e) => e.payload).toList();
      final app = await _appIfVersionChanged();
      final result = await _repo.sendBatch(
        events: events,
        trigger: trigger,
        app: app,
      );
      final done = {...result.acked, ...result.duplicates};
      final rest = <QueuedAnalyticsEvent>[];
      for (final item in items) {
        if (done.contains(item.eventId)) continue;
        if (batch.any((b) => b.eventId == item.eventId)) {
          item.retries += 1;
          if (item.retries >= AnalyticsQueue.maxRetries) continue;
        }
        rest.add(item);
      }
      await _queue.save(rest);
    } catch (_) {
      // Keep queue; next flush retries.
    } finally {
      _flushing = false;
    }
  }

  Future<Map<String, dynamic>?> _appIfVersionChanged() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final key = '${pkg.version}+${pkg.buildNumber}';
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/analytics_app_version.txt');
      final prev = await file.exists() ? await file.readAsString() : '';
      if (prev == key) return null;
      await file.writeAsString(key);
      final snap = await collectDeviceSnapshot();
      return {
        'version': pkg.version,
        'build': pkg.buildNumber,
        'platform': snap.platform,
      };
    } catch (_) {
      return null;
    }
  }
}

final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  final tracker = AnalyticsTracker(ref);
  ref.onDispose(() => unawaited(tracker.stop()));
  return tracker;
});

class AnalyticsNavObserver extends NavigatorObserver {
  AnalyticsNavObserver(this._onChange);

  final VoidCallback _onChange;

  void _tick() => _onChange();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _tick();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _tick();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _tick();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _tick();
}
