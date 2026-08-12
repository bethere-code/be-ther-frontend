import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../network/api_client.dart';
import 'deep_link_utils.dart';

/// Holds a deep-link path until the user is authenticated / hydrated.
class PendingDeepLinkNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPending(String? path) => state = path;

  void clearPending() => state = null;
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, String?>(PendingDeepLinkNotifier.new);

class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenLinks();
    _handleInitialLink();
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _routeFromUri(uri);
  }

  void _listenLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      _routeFromUri(uri);
    });
  }

  void _routeFromUri(Uri uri) {
    final route = eventRouteFromUri(uri);
    if (route == null) return;

    final auth = ref.read(authNotifierProvider);

    // Tokens not loaded yet — stash and let splash / redirect finish hydrate.
    // Do NOT send the user to Launch (that looked like a sign-out).
    if (!auth.isReady || !auth.isAuthenticated) {
      ref.read(pendingDeepLinkProvider.notifier).setPending(route);
      if (auth.isReady && !auth.isAuthenticated) {
        ref.read(goRouterRefreshProvider).refresh();
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      final current = router.state.uri.path;
      if (current == route) return;
      // Already in the app with a stack → push so hardware back returns here.
      // Cold open / replace stack → go; SharedEventScreen PopScope sends to feed.
      final onShell = current == FeedScreen.path ||
          current.startsWith('/explore') ||
          current.startsWith('/profile') ||
          current.startsWith('/notifications') ||
          current.startsWith('/search') ||
          current.startsWith('/add');
      if (onShell || router.canPop()) {
        router.push(route);
      } else {
        router.go(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
