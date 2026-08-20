import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/explore/presentation/explore_providers.dart';
import '../../features/feed/presentation/feed_providers.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/profile/presentation/profile_providers.dart';
import '../../features/search/presentation/search_providers.dart';
import '../background_tasks/notification_syncer.dart';

enum NetStatus { checking, offline, online }

/// Origin `/health` from `API_BASE_URL` (e.g. https://be-ther.com/api/ → /health).
Uri healthUriFromApiBase(String apiBase) {
  return Uri.parse(apiBase).resolve('/health');
}

bool hasNetworkLink(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

/// App-wide link + reachability. Wi‑Fi without internet still counts as offline.
class ConnectivityController extends Notifier<NetStatus> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  int _gen = 0;
  bool _recovering = false;

  @override
  NetStatus build() {
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    Future.microtask(_listen);
    return NetStatus.checking;
  }

  Future<void> _listen() async {
    final connectivity = Connectivity();
    _sub = connectivity.onConnectivityChanged.listen((_) => _scheduleCheck());
    await checkNow();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    // Brief debounce so flap / airplane-mode toggles don't thrash the UI.
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(checkNow());
    });
  }

  Future<void> checkNow() async {
    final gen = ++_gen;
    final results = await Connectivity().checkConnectivity();
    if (gen != _gen) return;

    if (!hasNetworkLink(results)) {
      state = NetStatus.offline;
      return;
    }

    final reachable = await _probeReachable();
    if (gen != _gen) return;

    final wasOffline = state == NetStatus.offline;
    if (!reachable) {
      state = NetStatus.offline;
      return;
    }

    state = NetStatus.online;
    if (wasOffline) {
      await _recoverSessionAndCaches();
    }
  }

  Future<bool> _probeReachable() async {
    final base = dotenv.maybeGet('API_BASE_URL')?.trim();
    if (base == null || base.isEmpty) return false;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        // Any HTTP response means the network path works.
        validateStatus: (_) => true,
      ),
    );
    try {
      final res = await dio.getUri(healthUriFromApiBase(base));
      return res.statusCode != null;
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }

  /// Soft re-auth + refresh main Riverpod caches after the network returns.
  Future<void> _recoverSessionAndCaches() async {
    if (_recovering) return;
    _recovering = true;
    try {
      final auth = ref.read(authNotifierProvider);
      if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
        await ref.read(authNotifierProvider.notifier).hydrateFromStorage();
      }
      ref.invalidate(feedProvider);
      ref.invalidate(exploreEventsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(profileMeProvider);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(searchResultsProvider);
      ref.read(notificationSyncerProvider).syncNow();
    } finally {
      _recovering = false;
    }
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityController, NetStatus>(ConnectivityController.new);
