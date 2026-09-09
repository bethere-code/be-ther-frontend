import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/analytics/analytics_tracker.dart';
import '../../../core/auth/welcome_pending.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

class AuthState {
  const AuthState({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.isReady = false,
    this.pendingWelcome = false,
  });

  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;

  /// False until [AuthNotifier.hydrateFromStorage] finishes (success or clear).
  final bool isReady;

  /// Show the one-shot welcome dialog on next feed entry.
  final bool pendingWelcome;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
    bool? isReady,
    bool? pendingWelcome,
    bool clearUser = false,
  }) {
    return AuthState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: clearUser ? null : (user ?? this.user),
      isReady: isReady ?? this.isReady,
      pendingWelcome: pendingWelcome ?? this.pendingWelcome,
    );
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(unauthenticatedDioProvider);
  return AuthRepository(dio);
});

/// Plain Dio for auth endpoints (no bearer injection / refresh loop).
final unauthenticatedDioProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.maybeGet('API_BASE_URL')?.trim();
  if (baseUrl == null || baseUrl.isEmpty) {
    throw StateError('API_BASE_URL missing in assets/env/app.env');
  }
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
});

class AuthNotifier extends Notifier<AuthState> {
  Future<void>? _hydrateInFlight;

  @override
  AuthState build() {
    // Start unready so deep links cannot treat "tokens not loaded yet" as signed-out.
    return const AuthState(isReady: false);
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  Future<void> _persistUser(Map<String, dynamic>? user) async {
    if (user == null) return;
    await _storage.writeUser(user);
  }

  /// Prefer a fresh profile; never drop an existing/cached user while logged in.
  Map<String, dynamic>? _keepUser(
    Map<String, dynamic>? next, {
    Map<String, dynamic>? cached,
  }) {
    return next ?? state.user ?? cached;
  }

  Future<void> hydrateFromStorage() async {
    if (_hydrateInFlight != null) {
      await _hydrateInFlight;
      return;
    }

    Future<Null> run() async {
      final (access, refresh) = await _storage.read();
      final cachedUser = await _storage.readUser();

      if (refresh == null || refresh.isEmpty) {
        state = const AuthState(isReady: true);
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final hasAccess = access != null && access.isNotEmpty;

      // Restore tokens + cached profile immediately so the shell never flashes
      // empty while /me or refresh is in flight.
      state = AuthState(
        accessToken: hasAccess ? access : null,
        refreshToken: refresh,
        user: cachedUser,
        isReady: false,
      );

      if (hasAccess) {
        try {
          final user = await repo.me(access);
          await _persistUser(user);
          state = AuthState(
            accessToken: access,
            refreshToken: refresh,
            user: user,
            isReady: true,
          );
          return;
        } on ApiException catch (e) {
          final authExpired = e.statusCode == 401 || e.statusCode == 403;
          if (!authExpired) {
            // Offline or server error — keep tokens + cached user.
            state = AuthState(
              accessToken: access,
              refreshToken: refresh,
              user: _keepUser(null, cached: cachedUser),
              isReady: true,
            );
            return;
          }
        } catch (_) {
          state = AuthState(
            accessToken: access,
            refreshToken: refresh,
            user: _keepUser(null, cached: cachedUser),
            isReady: true,
          );
          return;
        }
      }

      final restored = await _restoreViaRefresh(refresh, cachedUser: cachedUser);
      if (!restored) {
        await _storage.clear();
        state = const AuthState(isReady: true);
      }
    }

    _hydrateInFlight = run();
    try {
      await _hydrateInFlight;
    } finally {
      _hydrateInFlight = null;
    }
  }

  Future<void> applyTokens(AuthTokens tokens, {String authAction = 'login'}) async {
    await _storage.write(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    await _persistUser(tokens.user);
    // Welcome: brand-new accounts, or Google (etc.) from the signup screen
    // (`authAction: 'signup'` — including existing Google accounts).
    final pendingWelcome = shouldPendingWelcome(
      isNewUser: tokens.isNewUser,
      authAction: authAction,
    );
    state = AuthState(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: tokens.user,
      isReady: true,
      pendingWelcome: pendingWelcome,
    );
    unawaited(ref.read(analyticsTrackerProvider).onAuthenticated(authAction));
  }

  void consumePendingWelcome() {
    if (!state.pendingWelcome) return;
    state = state.copyWith(pendingWelcome: false);
  }

  Future<bool> tryRefresh() async {
    var refresh = state.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      // Deep-link / early API call before hydrate — read storage, never wipe.
      final (_, stored) = await _storage.read();
      refresh = stored;
    }
    if (refresh == null || refresh.isEmpty) return false;

    final ok = await _restoreViaRefresh(refresh);
    // Only clear a fully hydrated session; never wipe tokens mid-startup.
    if (!ok && state.isReady) {
      await logout();
    }
    return ok;
  }

  Future<bool> _restoreViaRefresh(
    String refreshToken, {
    Map<String, dynamic>? cachedUser,
  }) async {
    final previousUser = state.user ?? cachedUser;
    try {
      final repo = ref.read(authRepositoryProvider);
      final next = await repo.refresh(refreshToken);
      await _storage.write(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
      );

      Map<String, dynamic>? user = next.user;
      if (user == null) {
        try {
          user = await repo.me(next.accessToken);
        } catch (_) {
          // Tokens are valid; keep the previous/cached profile instead of nulling it.
        }
      }

      final kept = _keepUser(user, cached: previousUser);
      await _persistUser(kept);

      state = AuthState(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        user: kept,
        isReady: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    // Clear session first so the UI can leave immediately. Push / analytics /
    // Google sign-out are slow network work and must not block the handoff.
    await _storage.clear();
    state = const AuthState(isReady: true);
    unawaited(_cleanupAfterLogout());
  }

  Future<void> _cleanupAfterLogout() async {
    try {
      await ref.read(pushServiceProvider).stopOnLogout();
    } catch (_) {}
    try {
      await ref.read(analyticsTrackerProvider).onLogout();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  void updateUser(Map<String, dynamic> patch) {
    final u = state.user;
    if (u == null) return;
    final next = {...u, ...patch};
    state = state.copyWith(user: next);
    // Fire-and-forget; UI already has the updated map in memory.
    _persistUser(next);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
