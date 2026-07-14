import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../network/api_client.dart';
import 'deep_link_utils.dart';

/// Holds a deep-link path until the user is authenticated.
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
    if (!auth.isAuthenticated) {
      ref.read(pendingDeepLinkProvider.notifier).setPending(route);
      ref.read(goRouterRefreshProvider).refresh();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(route);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
