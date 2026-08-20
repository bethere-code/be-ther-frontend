import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/block_session.dart';
import '../../search/presentation/search_screen.dart';
import 'explore_providers.dart';
import 'widgets/explore_event_tile.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(exploreEventsProvider);
    final deletedIds = ref.watch(deletedPostIdsProvider);
    final blockedUsernames = ref.watch(sessionBlockedUsernamesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(FeedScreen.path);
      },
      child: AppShell(
        activeTab: ShellTab.explore,
        showRail: true,
        header: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                InkWell(
                  onTap: _scrollToTop,
                  child: Image.asset(
                    AppImages.betherNewLogo,
                    fit: BoxFit.contain,
                    width: 60,
                  ),
                ),
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
                    final visible = items
                        .where(
                          (e) =>
                              !deletedIds.contains(e.id) &&
                              !isAuthorSessionBlocked(
                                blockedUsernames,
                                e.author?.username,
                              ),
                        )
                        .toList(growable: false);
                    if (visible.isEmpty) {
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
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        crossAxisCount: ExploreEventTileLayout.crossAxisCount,
                        crossAxisSpacing: ExploreEventTileLayout.gridSpacing,
                        mainAxisSpacing: ExploreEventTileLayout.gridSpacing,
                        itemCount: visible.length,
                        itemBuilder: (context, i) =>
                            ExploreEventTile(event: visible[i]),
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
