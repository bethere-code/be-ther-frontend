import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../feed/presentation/widgets/feed_post_card.dart';

class SharedEventScreen extends ConsumerWidget {
  const SharedEventScreen({super.key, required this.postId});

  final String postId;

  /// Must match public share URLs: `https://be-ther.com/e/:postId`.
  static const path = '/e/:postId';
  static const name = 'shared-event';

  static String pathFor(String id) => '/e/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostProvider(postId));
    const headerHeight = kToolbarHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
            padding: const EdgeInsets.only(right: 12),
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
              children: [
                IconButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(FeedScreen.path);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: AppColors.background),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(FeedScreen.path),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        AppImages.betherNewLogo,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/search'),
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.search, color: AppColors.background),
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
            error: (error, _) => _ErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onBack: () => context.go(FeedScreen.path),
            ),
            data: (item) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                FeedPostCard(
                  item: item,
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
