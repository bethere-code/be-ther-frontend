import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/feed/presentation/add_post_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/launch/presentation/launch_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/auth_email_screen.dart';
import '../../features/auth/presentation/auth_otp_route_extra.dart';
import '../../features/auth/presentation/auth_otp_screen.dart';
import '../../features/auth/presentation/auth_signup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../network/api_client.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: pageChild);
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: SplashScreen.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      final isSplash = loc == SplashScreen.path;
      if (isSplash) return null;

      final public = loc == LaunchScreen.path ||
          loc == OnboardingScreen.path ||
          loc == AuthEmailScreen.path ||
          loc == AuthSignupScreen.path ||
          loc == AuthOtpScreen.path;

      if (!auth.isAuthenticated && !public) {
        return LaunchScreen.path;
      }
      if (auth.isAuthenticated &&
          (loc == LaunchScreen.path || loc.startsWith('/auth/') || loc == OnboardingScreen.path)) {
        return FeedScreen.path;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: SplashScreen.path,
        name: SplashScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: LaunchScreen.path,
        name: LaunchScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const LaunchScreen()),
      ),
      GoRoute(
        path: OnboardingScreen.path,
        name: OnboardingScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AuthEmailScreen.path,
        name: AuthEmailScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const AuthEmailScreen()),
      ),
      GoRoute(
        path: AuthSignupScreen.path,
        name: AuthSignupScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const AuthSignupScreen()),
      ),
      GoRoute(
        path: AuthOtpScreen.path,
        name: AuthOtpScreen.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! AuthOtpRouteExtra || extra.identifier.isEmpty) {
            return _fadePage(state, const AuthEmailScreen());
          }
          return _fadePage(
            state,
            AuthOtpScreen(
              identifier: extra.identifier,
              destinationLabel: extra.destinationLabel,
              flow: extra.flow,
            ),
          );
        },
      ),
      GoRoute(
        path: FeedScreen.path,
        name: FeedScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const FeedScreen()),
      ),
      GoRoute(
        path: ExploreScreen.path,
        name: ExploreScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const ExploreScreen()),
      ),
      GoRoute(
        path: ProfileScreen.path,
        name: ProfileScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: NotificationsScreen.path,
        name: NotificationsScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: AddPostScreen.path,
        name: AddPostScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const AddPostScreen()),
      ),
      GoRoute(
        path: SettingsScreen.path,
        name: SettingsScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const SettingsScreen()),
      ),
    ],
  );
});
