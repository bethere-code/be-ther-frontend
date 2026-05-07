import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_notifier.dart';

final goRouterRefreshProvider = Provider<GoRouterRefresh>((ref) {
  final notifier = GoRouterRefresh();
  ref.listen(authNotifierProvider, (previous, next) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class GoRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

bool _isAuthPath(String path) {
  return path.contains('/api/v1/auth/');
}

final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.maybeGet('API_BASE_URL')?.trim();
  if (baseUrl == null || baseUrl.isEmpty) {
    throw StateError('API_BASE_URL missing in assets/env/app.env');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authNotifierProvider).accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 && !_isAuthPath(path)) {
          final ok = await ref.read(authNotifierProvider.notifier).tryRefresh();
          if (ok) {
            final token = ref.read(authNotifierProvider).accessToken;
            final req = error.requestOptions;
            req.headers['Authorization'] = 'Bearer $token';
            try {
              final clone = await dio.fetch(req);
              return handler.resolve(clone);
            } catch (e) {
              if (e is DioException) return handler.next(e);
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  ref.onDispose(dio.close);
  return dio;
});
