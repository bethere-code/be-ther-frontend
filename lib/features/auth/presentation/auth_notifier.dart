import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

class AuthState {
  const AuthState({this.accessToken, this.refreshToken, this.user});

  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
    bool clearUser = false,
  }) {
    return AuthState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: clearUser ? null : (user ?? this.user),
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
    return const AuthState();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  Future<void> hydrateFromStorage() async {
    if (_hydrateInFlight != null) {
      await _hydrateInFlight;
      return;
    }

    Future<Null> run() async {
      final (access, refresh) = await _storage.read();
      if (refresh == null || refresh.isEmpty) {
        state = const AuthState();
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final hasAccess = access != null && access.isNotEmpty;

      if (hasAccess) {
        try {
          final user = await repo.me(access);
          state = AuthState(
            accessToken: access,
            refreshToken: refresh,
            user: user,
          );
          return;
        } on ApiException catch (e) {
          final authExpired = e.statusCode == 401 || e.statusCode == 403;
          if (!authExpired) {
            // Offline or server error — keep tokens so the session survives relaunch.
            state = AuthState(accessToken: access, refreshToken: refresh);
            return;
          }
        } catch (_) {
          state = AuthState(accessToken: access, refreshToken: refresh);
          return;
        }
      }

      final restored = await _restoreViaRefresh(refresh);
      if (!restored) {
        await _storage.clear();
        state = const AuthState();
      }
    }

    _hydrateInFlight = run();
    try {
      await _hydrateInFlight;
    } finally {
      _hydrateInFlight = null;
    }
  }

  Future<void> applyTokens(AuthTokens tokens) async {
    await _storage.write(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    state = AuthState(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: tokens.user,
    );
  }

  Future<bool> tryRefresh() async {
    final refresh = state.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    final ok = await _restoreViaRefresh(refresh);
    if (!ok) await logout();
    return ok;
  }

  Future<bool> _restoreViaRefresh(String refreshToken) async {
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
          // Tokens are valid; profile can load after the first API call.
        }
      }

      state = AuthState(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        user: user,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await GoogleSignIn.instance.signOut();
    await _storage.clear();
    state = const AuthState();
  }

  void updateUser(Map<String, dynamic> patch) {
    final u = state.user;
    if (u == null) return;
    state = state.copyWith(user: {...u, ...patch});
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
