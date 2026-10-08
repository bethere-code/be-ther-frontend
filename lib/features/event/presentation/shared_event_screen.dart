import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_brand_logo.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../feed/data/posts_repository.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../feed/presentation/widgets/feed_post_card.dart';
import '../../profile/presentation/profile_screen.dart';

class SharedEventScreen extends ConsumerWidget {
  const SharedEventScreen({super.key, required this.postId});

  final String postId;

  /// Must match public share URLs: `https://be-ther.com/e/:postId`.
  static const path = '/e/:postId';
  static const name = 'shared-event';

  static String pathFor(String id) => '/e/$id';

  /// App-bar and hardware back: pop if possible, else land on feed
  /// (deep links often replace the stack so [canPop] is false).
  static void leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(FeedScreen.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostProvider(postId));
    const headerHeight = 52.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        leave(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: AppShell(
          activeTab: ShellTab.home,
          showRail: true,
          header: PreferredSize(
            preferredSize: const Size.fromHeight(headerHeight),
            child: Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: AppBrandLogo.headerInset,
              ),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: AppDimens.borderThick,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => leave(context),
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.background,
                    ),
                  ),
                  AppBrandLogo(onTap: () => context.go(FeedScreen.path)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/search'),
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.search,
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Container(
            color: AppColors.background,
            child: postAsync.when(
              loading: () => ListView(
                children: const [PostSkeleton()],
              ),
              error: (error, _) {
                if (error is PrivateEventAccess) {
                  return _PrivateEventState(
                    access: error,
                    onBack: () => leave(context),
                    onViewProfile: error.ownerUsername == null ||
                            error.ownerUsername!.isEmpty
                        ? null
                        : () => context.push(
                              ProfileScreen.pathForUser(error.ownerUsername!),
                            ),
                  );
                }
                return _ErrorState(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onBack: () => leave(context),
                );
              },
              data: (item) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  FeedPostCard(
                    post: item,
                    recordFeedImpression: false,
                    onInteractionChanged: () {
                      ref.invalidate(sharedPostProvider(postId));
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateEventState extends StatelessWidget {
  const _PrivateEventState({
    required this.access,
    required this.onBack,
    this.onViewProfile,
  });

  final PrivateEventAccess access;
  final VoidCallback onBack;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final name = access.ownerName?.trim();
    const title = 'Private event';
    final body = access.message;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.display(20, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(14, color: AppColors.mutedForeground),
            ),
            if (access.isProfilePrivate &&
                name != null &&
                name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Follow $name in Be Ther to see their events.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  13,
                  color: AppColors.mutedForeground,
                  weight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (onViewProfile != null) ...[
              FilledButton(
                onPressed: onViewProfile,
                child: Text(
                  name != null && name.isNotEmpty
                      ? 'VIEW $name\'S PROFILE'
                      : 'VIEW PROFILE',
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: onBack,
              child: const Text('BACK TO FEED'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              'Event unavailable',
              style: AppTextStyles.display(20, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBack,
              child: const Text('BACK TO FEED'),
            ),
          ],
        ),
      ),
    );
  }
}
