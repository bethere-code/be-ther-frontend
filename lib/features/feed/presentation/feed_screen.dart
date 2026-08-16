import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_images.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../../core/routing/app_route_observer.dart';
import '../../../core/utils/popup_menu_utils.dart';
import '../../profile/presentation/profile_providers.dart';
import '../data/posts_repository.dart';
import 'add_post_screen.dart';
import 'feed_providers.dart';
import 'widgets/feed_permissions_coordinator.dart';
import 'widgets/feed_post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  static const path = '/feed';
  static const name = 'feed';

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with RouteAware, WidgetsBindingObserver {
  late ScrollController _scrollController;
  final List<Map<String, dynamic>> _allItems = [];
  int? _nextSkip;
  bool _isLoadingMore = false;
  bool _hasBootstrapped = false;
  bool _routeSubscribed = false;
  bool _permissionCheckQueued = false;
  bool _wasCovered = false;
  bool _isRefreshing = false;
  GoRouter? _goRouter;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _schedulePermissionCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }

    final router = GoRouter.of(context);
    if (_goRouter != router) {
      _goRouter?.routerDelegate.removeListener(_onNavigation);
      _goRouter = router;
      router.routerDelegate.addListener(_onNavigation);
    }
  }

  @override
  void dispose() {
    _goRouter?.routerDelegate.removeListener(_onNavigation);
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavigation() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (GoRouterState.of(context).matchedLocation != FeedScreen.path) return;
    _schedulePermissionCheck();
    if (_wasCovered) {
      _wasCovered = false;
      _maybeSyncFromApi();
    }
  }

  @override
  void didPushNext() {
    _wasCovered = true;
  }

  @override
  void didPopNext() {
    _schedulePermissionCheck();
    _wasCovered = false;
    _maybeSyncFromApi();
  }

  void _maybeSyncFromApi() {
    // After creating an event we keep a local top insert; syncing when the
    // user returns (or later revisits) replaces it with the API feed.
    if (ref.read(feedLocalInsertsProvider).isEmpty) return;
    unawaited(_syncFromApi());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        GoRouterState.of(context).matchedLocation == FeedScreen.path) {
      _schedulePermissionCheck();
    }
  }

  void _schedulePermissionCheck() {
    if (_permissionCheckQueued) return;
    _permissionCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _permissionCheckQueued = false;
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final userRepo = ref.read(userRepositoryProvider);
      await FeedPermissionsCoordinator.ensure(
        context,
        userRepository: userRepo,
      );
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
    );
  }

  void _onScroll() {
    dismissOpenPopupMenus(context);
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  String _itemId(Map<String, dynamic> item) =>
      item['_id']?.toString() ??
      item['postId']?.toString() ??
      item['id']?.toString() ??
      '';

  void _applyFirstPage(FeedPage page) {
    _allItems
      ..clear()
      ..addAll(page.items);
    _nextSkip = page.nextSkip;
    _hasBootstrapped = true;
  }

  List<Map<String, dynamic>> _mergeVisibleItems({
    required List<Map<String, dynamic>> sourceItems,
    required List<Map<String, dynamic>> localInserts,
    required Set<String> deletedIds,
  }) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    void addAll(Iterable<Map<String, dynamic>> items) {
      for (final item in items) {
        final id = _itemId(item);
        if (id.isNotEmpty) {
          if (deletedIds.contains(id) || !seen.add(id)) continue;
        }
        merged.add(item);
      }
    }

    addAll(localInserts);
    addAll(sourceItems);
    return merged;
  }

  Future<void> _loadMore() async {
    final skip = _nextSkip;
    if (_isLoadingMore || skip == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await ref.read(feedPageProvider(skip).future);
      if (!mounted) return;

      final seen = _allItems.map(_itemId).where((id) => id.isNotEmpty).toSet();
      final fresh = page.items.where((item) {
        final id = _itemId(item);
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

  Future<void> _syncFromApi() async {
    try {
      await _refresh();
    } catch (_) {
      // Keep local inserts if the refresh fails.
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _nextSkip = null;
    _isLoadingMore = false;
    try {
      final page = await ref.refresh(feedProvider.future);
      if (!mounted) return;
      // Clear optimistic inserts only after API data arrives so the new
      // event does not disappear during the round-trip.
      ref.read(feedLocalInsertsProvider.notifier).clear();
      setState(() => _applyFirstPage(page));
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final deletedIds = ref.watch(deletedPostIdsProvider);
    final localInserts = ref.watch(feedLocalInsertsProvider);

    // First page only — never reset scroll by re-applying while paginating.
    ref.listen<AsyncValue<FeedPage>>(feedProvider, (prev, next) {
      next.whenData((page) {
        if (!mounted || _hasBootstrapped) return;
        setState(() => _applyFirstPage(page));
      });
    });

    ref.listen<List<Map<String, dynamic>>>(feedLocalInsertsProvider, (
      prev,
      next,
    ) {
      if (next.isEmpty) return;
      if (prev != null && next.length <= prev.length) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToTop();
      });
    });

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
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 52,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: InkWell(
                    onTap: _scrollToTop,
                    child: Image.asset(
                      AppImages.betherNewLogo,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/search'),
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(Icons.search, color: AppColors.background),
                ),
              ],
            ),
          ),
        ),
        child: Container(
          color: AppColors.background,
          child: feed.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            data: (page) {
              final sourceItems =
                  _hasBootstrapped ? _allItems : page.items;

              final visibleItems = _mergeVisibleItems(
                sourceItems: sourceItems,
                localInserts: localInserts,
                deletedIds: deletedIds,
              );

              if (!_hasBootstrapped) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _hasBootstrapped) return;
                  setState(() => _applyFirstPage(page));
                });
              }

              if (visibleItems.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _FeedEmptyState(
                          onCreatePost: () => context.push(AddPostScreen.path),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      visibleItems.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == visibleItems.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final item = visibleItems[index];
                    return RepaintBoundary(
                      child: FeedPostCard(
                        key: ValueKey(_itemId(item)),
                        item: item,
                      ),
                    );
                  },
                ),
              );
            },
            loading: () {
              if (localInserts.isEmpty) {
                return ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) => const PostSkeleton(),
                );
              }
              final visibleItems = _mergeVisibleItems(
                sourceItems: const [],
                localInserts: localInserts,
                deletedIds: deletedIds,
              );
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return RepaintBoundary(
                      child: FeedPostCard(
                        key: ValueKey(_itemId(item)),
                        item: item,
                      ),
                    );
                  },
                ),
              );
            },
            error: (e, _) => Center(child: SelectableText('$e')),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with illustration-style icon and primary CTA.
class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({required this.onCreatePost});

  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FeedEmptyCartoonIcon(),
          const SizedBox(height: 24),
          Text(
            'Nothing here yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              22,
              color: AppColors.secondary,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share where you\'ve been or where you\'re going — your feed starts with your first post.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              15,
              color: AppColors.mutedForeground,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: onCreatePost,
              child: Text(
                'CREATE POST',
                style: AppTextStyles.display(
                  16,
                  color: AppColors.primaryForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple “cartoon” stack: soft shapes + mascot-style icon.
class _FeedEmptyCartoonIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.border,
                width: AppDimens.borderThick,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.accent,
                  offset: Offset(6, 6),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          Icon(
            Icons.travel_explore_rounded,
            size: 64,
            color: AppColors.primary,
            shadows: const [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 0,
                color: AppColors.border,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
