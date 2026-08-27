import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../feed/domain/edited_post_overlay.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/block_session.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/explore_event.dart';
import '../domain/explore_page.dart';
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
  final List<ExploreEvent> _allItems = [];
  int? _nextSkip;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasBootstrapped = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  void _applyFirstPage(ExplorePage page) {
    _allItems
      ..clear()
      ..addAll(page.items);
    _nextSkip = page.nextSkip;
    _hasBootstrapped = true;
  }

  Future<void> _loadMore() async {
    final skip = _nextSkip;
    if (_isLoadingMore || skip == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await ref.read(explorePageProvider(skip).future);
      if (!mounted) return;

      final seen = _allItems.map((e) => e.id).where((id) => id.isNotEmpty).toSet();
      final fresh = page.items.where((item) {
        final id = item.id;
        return id.isEmpty || seen.add(id);
      });

      setState(() {
        _allItems.addAll(fresh);
        _nextSkip = page.nextSkip;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _nextSkip = null;
    _isLoadingMore = false;
    try {
      final page = await ref.refresh(exploreEventsProvider.future);
      if (!mounted) return;
      ref.read(editedPostsProvider.notifier).clear();
      setState(() => _applyFirstPage(page));
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(exploreEventsProvider);
    final deletedIds = ref.watch(deletedPostIdsProvider);
    final discoveryHiddenIds = ref.watch(discoveryHiddenPostIdsProvider);
    final blockedAuthors = ref.watch(sessionBlockedAuthorsProvider);
    final editedPosts = ref.watch(editedPostsProvider);

    // Seed local list from first provider page (same pattern as feed).
    events.whenData((page) {
      if (!_hasBootstrapped && !_isRefreshing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasBootstrapped) return;
          setState(() => _applyFirstPage(page));
        });
      }
    });

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
                  data: (_) {
                    final source = _hasBootstrapped
                        ? _allItems
                        : (events.asData?.value.items ?? const <ExploreEvent>[]);
                    final visible = overlayEditedExploreEvents(
                      source.where(
                        (e) =>
                            !deletedIds.contains(e.id) &&
                            !discoveryHiddenIds.contains(e.id) &&
                            !isAuthorSessionBlocked(
                              blockedAuthors,
                              username: e.author?.username,
                              userId: e.author?.id,
                            ),
                      ),
                      editedPosts,
                    );
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
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            sliver: SliverMasonryGrid.count(
                              crossAxisCount: ExploreEventTileLayout.crossAxisCount,
                              crossAxisSpacing: ExploreEventTileLayout.gridSpacing,
                              mainAxisSpacing: ExploreEventTileLayout.gridSpacing,
                              childCount: visible.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i >= visible.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                }
                                return RepaintBoundary(
                                  child: ExploreEventTile(event: visible[i]),
                                );
                              },
                            ),
                          ),
                        ],
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
