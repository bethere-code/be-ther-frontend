import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/shell_header_avatar.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../search/presentation/search_screen.dart';
import 'explore_providers.dart';
import 'widgets/explore_event_tile.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(exploreEventsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(FeedScreen.path);
      },
      child: AppShell(
        activeTab: ShellTab.explore,
        header: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const ShellHeaderAvatar(),
                Expanded(
                  child: Center(
                    child: Text(
                      'EXPLORE',
                      style: AppTextStyles.display(
                        28,
                        color: AppColors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(SearchScreen.path),
                  icon: const Icon(
                    Icons.search,
                    color: AppColors.background,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopUpcomingHeader(),
              Expanded(
                child: events.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No posts to explore yet',
                          style: AppTextStyles.body(
                            16,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.card,
                      onRefresh: () =>
                          ref.refresh(exploreEventsProvider.future),
                      child: MasonryGridView.count(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        crossAxisCount: ExploreEventTileLayout.crossAxisCount,
                        crossAxisSpacing: ExploreEventTileLayout.gridSpacing,
                        mainAxisSpacing: ExploreEventTileLayout.gridSpacing,
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            ExploreEventTile(event: items[i]),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        '$e',
                        style: AppTextStyles.body(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopUpcomingHeader extends StatelessWidget {
  const _TopUpcomingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThin,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'LATEST EVENTS',
            style: AppTextStyles.display(
              20,
              color: AppColors.secondary,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}
