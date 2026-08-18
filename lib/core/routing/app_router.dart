import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/event/presentation/shared_event_screen.dart';
import '../../features/feed/presentation/add_post_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/launch/presentation/launch_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_connections_screen.dart';
import '../../features/profile/presentation/profile_events_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/auth_email_screen.dart';
import '../../features/auth/presentation/auth_otp_route_extra.dart';
import '../../features/auth/presentation/auth_otp_screen.dart';
import '../../features/auth/presentation/auth_signup_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../network/api_client.dart';
import 'app_route_observer.dart';
import 'deep_link_listener.dart';
import 'deep_link_utils.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (MediaQuery.disableAnimationsOf(context)) return pageChild;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: pageChild);
    },
  );
}

CustomTransitionPage<void> _sheetPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    barrierColor: Colors.transparent,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (MediaQuery.disableAnimationsOf(context)) return pageChild;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: pageChild),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Always start on splash. Platform deep links are handled by
    // [DeepLinkListener] after auth hydrate — otherwise `/e/...` opens
    // before tokens load and redirect treats the user as signed out.
    initialLocation: SplashScreen.path,
    overridePlatformDefaultLocation: true,
    observers: [appRouteObserver],
    refreshListenable: refresh,
    redirect: (context, state) {
      // Normalize share / platform deep links before auth gates.
      final fromDeepLink = eventRouteFromUri(state.uri);
      if (fromDeepLink != null && state.uri.path != fromDeepLink) {
        return fromDeepLink;
      }

      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      final isSplash = loc == SplashScreen.path;

      // Hold deep links until splash finishes hydrateFromStorage.
      if (!auth.isReady) {
        if (fromDeepLink != null || SharedEventPaths.isEventLocation(loc)) {
          ref
              .read(pendingDeepLinkProvider.notifier)
              .setPending(fromDeepLink ?? loc);
        }
        if (!isSplash) return SplashScreen.path;
        return null;
      }

      if (isSplash) return null;

      final public = loc == LaunchScreen.path ||
          loc == OnboardingScreen.path ||
          loc == AuthEmailScreen.path ||
          loc == AuthSignupScreen.path ||
          loc == AuthOtpScreen.path;

      if (!auth.isAuthenticated && !public) {
        if (SharedEventPaths.isEventLocation(loc) ||
            (fromDeepLink != null && SharedEventPaths.isEventLocation(fromDeepLink))) {
          ref
              .read(pendingDeepLinkProvider.notifier)
              .setPending(fromDeepLink ?? loc);
        }
        return LaunchScreen.path;
      }
      if (auth.isAuthenticated &&
          (loc == LaunchScreen.path || loc.startsWith('/auth/') || loc == OnboardingScreen.path)) {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null && pending.isNotEmpty) {
          ref.read(pendingDeepLinkProvider.notifier).clearPending();
          return pending;
        }
        return FeedScreen.path;
      }
      return null;
    },
    errorBuilder: (context, state) {
      final recovered = eventRouteFromUri(state.uri);
      if (recovered != null) {
        return _DeepLinkRecoveryPage(target: recovered);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.error?.toString() ?? 'Page not found',
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: () => context.go(FeedScreen.path),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      );
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
        path: SharedEventScreen.path,
        name: SharedEventScreen.name,
        pageBuilder: (context, state) => _fadePage(
          state,
          SharedEventScreen(postId: state.pathParameters['postId'] ?? ''),
        ),
      ),
      // Legacy alias from earlier builds.
      GoRoute(
        path: '/event/:postId',
        redirect: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          return id.isEmpty ? FeedScreen.path : SharedEventScreen.pathFor(id);
        },
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
        routes: [
          GoRoute(
            path: ':username',
            name: 'profile-user',
            pageBuilder: (context, state) => _fadePage(
              state,
              ProfileScreen(username: state.pathParameters['username']),
            ),
            routes: [
              GoRoute(
                path: 'events',
                name: ProfileEventsScreen.name,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  ProfileEventsScreen(
                    username: state.pathParameters['username'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: 'followers',
                name: ProfileConnectionsScreen.followersName,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  ProfileConnectionsScreen(
                    username: state.pathParameters['username'] ?? '',
                    mode: ProfileConnectionsMode.followers,
                  ),
                ),
              ),
              GoRoute(
                path: 'following',
                name: ProfileConnectionsScreen.followingName,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  ProfileConnectionsScreen(
                    username: state.pathParameters['username'] ?? '',
                    mode: ProfileConnectionsMode.following,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: NotificationsScreen.path,
        name: NotificationsScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: AddPostScreen.path,
        name: AddPostScreen.name,
        pageBuilder: (context, state) => _sheetPage(state, const AddPostScreen()),
      ),
      GoRoute(
        path: SearchScreen.path,
        name: SearchScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const SearchScreen()),
      ),
      GoRoute(
        path: SettingsScreen.path,
        name: SettingsScreen.name,
        pageBuilder: (context, state) => _fadePage(state, const SettingsScreen()),
      ),
    ],
  );
});

/// Recovers from unmatched deep-link locations by navigating to the event route.
class _DeepLinkRecoveryPage extends StatefulWidget {
  const _DeepLinkRecoveryPage({required this.target});

  final String target;

  @override
  State<_DeepLinkRecoveryPage> createState() => _DeepLinkRecoveryPageState();
}

class _DeepLinkRecoveryPageState extends State<_DeepLinkRecoveryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(widget.target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
