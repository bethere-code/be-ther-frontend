import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      if (access == null ||
          refresh == null ||
          access.isEmpty ||
          refresh.isEmpty) {
        state = const AuthState();
        return;
      }
      try {
        final repo = ref.read(authRepositoryProvider);
        final user = await repo.me(access);
        state = AuthState(
          accessToken: access,
          refreshToken: refresh,
          user: user,
        );
      } catch (_) {
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
    try {
      final repo = ref.read(authRepositoryProvider);
      final next = await repo.refresh(refresh);
      await _storage.write(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
      );
      state = AuthState(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        user: state.user,
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    await GoogleSignIn.instance.signOut();
    await _storage.clear();
    state = const AuthState();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
