import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_colors.dart';
import 'core/routing/app_router.dart';
import 'core/routing/deep_link_listener.dart';
import 'core/theme/app_theme.dart';

class BeTherApp extends ConsumerWidget {
  const BeTherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Be Ther',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return DeepLinkListener(
          child: ColoredBox(
            color: AppColors.background,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
