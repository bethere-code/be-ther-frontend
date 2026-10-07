import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/feed/presentation/feed_screen.dart';

/// Open a main shell tab without stacking duplicates.
/// Uses [push] so Android/iOS back returns to where the user came from
/// ([go] replaced the stack and made back exit the app).
void pushShellTab(BuildContext context, String path) {
  final loc = GoRouterState.of(context).uri.path;
  if (loc == path) return;
  context.push(path);
}

/// System back on a shell tab: pop if there is a stack, else land on feed.
/// Never leaves the user with an empty stack (app exit) from profile/alerts/explore.
void popShellOrGoHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(FeedScreen.path);
  }
}
