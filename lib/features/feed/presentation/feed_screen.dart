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
  List<Map<String, dynamic>> _allItems = [];
  int _currentSkip = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _routeSubscribed = false;
  bool _permissionCheckQueued = false;
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
  }

  @override
  void didPopNext() {
    _schedulePermissionCheck();
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

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentSkip += 10;
    });
  }

  void _resetPagination() {
    setState(() {
      _allItems.clear();
      _currentSkip = 0;
      _isLoadingMore = false;
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initial load or refresh
    final feed = _currentSkip == 0
        ? ref.watch(feedProvider)
        : ref.watch(feedPageProvider(_currentSkip));
    final deletedIds = ref.watch(deletedPostIdsProvider);

    // const feedHeaderHeight = kToolbarHeight;

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
            data: (page) {
              // Update pagination state based on new data
              if (_currentSkip == 0) {
                _allItems = page.items;
                _hasMore = page.nextSkip != null;
              } else if (_currentSkip > 0) {
                _allItems.addAll(page.items);
                _hasMore = page.nextSkip != null;
              }

              if (mounted && _isLoadingMore) {
                setState(() => _isLoadingMore = false);
              }

              final visibleItems = deletedIds.isEmpty
                  ? _allItems
                  : _allItems
                      .where((item) {
                        final id = item['_id']?.toString() ??
                            item['id']?.toString() ??
                            '';
                        return id.isEmpty || !deletedIds.contains(id);
                      })
                      .toList(growable: false);

              if (visibleItems.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    _resetPagination();
                    final _ = await ref.refresh(feedProvider.future);
                  },
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
                onRefresh: () async {
                  _resetPagination();
                  final _ = await ref.refresh(feedProvider.future);
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visibleItems.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == visibleItems.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final item = visibleItems[index];
                    return RepaintBoundary(child: FeedPostCard(item: item));
                  },
                ),
              );
            },
            loading: () => ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const PostSkeleton(),
            ),
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
