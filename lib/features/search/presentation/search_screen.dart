import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../explore/domain/explore_event.dart';
import '../../explore/presentation/widgets/explore_event_tile.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../profile/presentation/block_session.dart';
import '../domain/search_post.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const path = '/search';
  static const name = 'search';

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounce = Duration(milliseconds: 350);

  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;
  final GlobalKey _searchHeaderKey = GlobalKey();
  Timer? _debounceTimer;

  final List<ExploreEvent> _results = [];
  int _skip = 0;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _activeQuery = '';
  String? _appliedKey;

  /// Monotonic generation — only the latest committed search may paint results.
  int _generation = 0;
  int _appliedGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Dismiss keyboard on taps outside the search header (tiles, empty area, etc.).
  void _unfocusIfOutsideSearch(Offset globalPosition) {
    if (!_searchFocusNode.hasFocus) return;
    final headerCtx = _searchHeaderKey.currentContext;
    if (headerCtx != null) {
      final box = headerCtx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.contains(globalPosition)) return;
      }
    }
    _searchFocusNode.unfocus();
  }

  void _dismissKeyboard() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 500) {
      return;
    }
    _loadMore();
  }

  void _scheduleSearch(String raw) {
    _debounceTimer?.cancel();
    final trimmed = raw.trim();

    // Invalidate in-flight results immediately on every keystroke (incl. backspace)
    // so a slower previous response cannot paint over the newer field value.
    if (trimmed != _activeQuery) {
      setState(() {
        _generation += 1;
        _appliedKey = null;
        if (trimmed.isEmpty) {
          _activeQuery = '';
          _skip = 0;
          _loadingMore = false;
          _hasMore = true;
          _results.clear();
        } else {
          // Drop stale cards while debounce waits for the new query.
          _results.clear();
          _skip = 0;
          _loadingMore = false;
          _hasMore = true;
        }
      });
    } else {
      setState(() {}); // refresh clear / SEARCH button styling
    }

    if (trimmed.isEmpty) return;

    final scheduledGen = _generation;
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      // Field moved again (more typing / backspace) — abandon this commit.
      if (_controller.text.trim() != trimmed) return;
      if (scheduledGen != _generation) return;
      _commitQuery(trimmed);
    });
  }

  void _commitQuery(String query) {
    _debounceTimer?.cancel();
    // Re-read field so backspace after SEARCH tap cannot commit stale text.
    final resolved = query;
    if (resolved == _activeQuery && _skip == 0 && _results.isNotEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _generation += 1;
      _activeQuery = resolved;
      _skip = 0;
      _loadingMore = false;
      _hasMore = true;
      _results.clear();
      _appliedKey = null;
    });
  }

  void _submitSearch() {
    _dismissKeyboard();
    _debounceTimer?.cancel();
    _commitQuery(_controller.text.trim());
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _generation += 1;
      _activeQuery = '';
      _skip = 0;
      _loadingMore = false;
      _hasMore = true;
      _results.clear();
      _appliedKey = null;
    });
  }

  void _loadMore() {
    if (_activeQuery.isEmpty || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _skip += 10;
      _appliedKey = null;
    });
  }

  String _pageKey(SearchPage page) =>
      '$_generation|$_activeQuery|$_skip|${page.items.length}|${page.nextSkip}|${page.items.isEmpty ? '-' : page.items.first.id}';

  void _applyPage(SearchPage page, int generation) {
    if (!mounted) return;
    if (generation != _generation) return; // race: stale response
    // Field diverged (backspace/typing) before this frame applied.
    if (_controller.text.trim() != _activeQuery) return;
    final key = _pageKey(page);
    if (key == _appliedKey) return;
    setState(() {
      _appliedKey = key;
      _appliedGeneration = generation;
      if (_skip == 0) {
        _results
          ..clear()
          ..addAll(page.items);
      } else {
        final seen = _results.map((e) => e.id).toSet();
        for (final item in page.items) {
          if (seen.add(item.id)) _results.add(item);
        }
      }
      _hasMore = page.nextSkip != null;
      _loadingMore = false;
    });
  }

  List<ExploreEvent> _displayItems(SearchPage page) {
    final deleted = ref.read(deletedPostIdsProvider);
    final blocked = ref.read(sessionBlockedUsernamesProvider);
    List<ExploreEvent> raw;
    if (_skip == 0) {
      raw = page.items;
    } else if (_results.isEmpty) {
      raw = page.items;
    } else {
      raw = List<ExploreEvent>.unmodifiable(_results);
    }
    if (deleted.isEmpty && blocked.isEmpty) return raw;
    return raw
        .where(
          (e) =>
              !deleted.contains(e.id) &&
              !isAuthorSessionBlocked(blocked, e.author?.username),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final fieldQuery = _controller.text.trim();
    final awaitingDebounce =
        fieldQuery.isNotEmpty && fieldQuery != _activeQuery;

    final params = (query: _activeQuery, skip: _skip);
    final asyncResults = ref.watch(searchResultsProvider(params));
    ref.watch(deletedPostIdsProvider);
    ref.watch(sessionBlockedUsernamesProvider);
    final genAtWatch = _generation;

    return AppShell(
      activeTab: ShellTab.home,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _unfocusIfOutsideSearch(event.position),
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            children: [
              KeyedSubtree(
                key: _searchHeaderKey,
                child: _SearchHeader(
                  controller: _controller,
                  focusNode: _searchFocusNode,
                  canSearch: fieldQuery.isNotEmpty,
                  onChanged: _scheduleSearch,
                  onSubmit: _submitSearch,
                  onClear: _clearSearch,
                  onSearchTap: _submitSearch,
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _dismissKeyboard();
                    }
                    return false;
                  },
                  child: fieldQuery.isEmpty
                      ? const _SearchIdle()
                      : awaitingDebounce
                          ? const _SearchLoadingGrid()
                          : asyncResults.when(
                              data: (page) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _applyPage(page, genAtWatch);
                                });
                                if (_activeQuery.isEmpty) {
                                  return const _SearchIdle();
                                }
                                return _SearchBody(
                                  query: _activeQuery,
                                  results: _displayItems(page),
                                  loadingMore: _loadingMore && _hasMore,
                                  scrollController: _scrollController,
                                  resultCount: _skip == 0
                                      ? page.items.length
                                      : _results.length,
                                  hasMore: page.nextSkip != null ||
                                      (_hasMore && _results.isNotEmpty),
                                );
                              },
                              loading: () => _skip > 0 && _results.isNotEmpty
                                  ? _SearchBody(
                                      query: _activeQuery,
                                      results:
                                          List<ExploreEvent>.unmodifiable(
                                        _results,
                                      ),
                                      loadingMore: true,
                                      scrollController: _scrollController,
                                      resultCount: _results.length,
                                      hasMore: true,
                                    )
                                  : const _SearchLoadingGrid(),
                              error: (error, _) {
                                final msg = '$error';
                                if (msg.contains('cancelled') &&
                                    _results.isNotEmpty &&
                                    _appliedGeneration == _generation) {
                                  return _SearchBody(
                                    query: _activeQuery,
                                    results: List<ExploreEvent>.unmodifiable(
                                      _results,
                                    ),
                                    loadingMore: false,
                                    scrollController: _scrollController,
                                    resultCount: _results.length,
                                    hasMore: _hasMore,
                                  );
                                }
                                if (msg.contains('cancelled')) {
                                  return const _SearchLoadingGrid();
                                }
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: SelectableText(
                                      msg,
                                      style: AppTextStyles.body(14),
                                    ),
                                  ),
                                );
                              },
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

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.canSearch,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSearch;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              style: AppTextStyles.body(15, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Event, venue, city, area, state…',
                hintStyle: AppTextStyles.body(
                  14,
                  color: AppColors.mutedForeground,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.mutedForeground,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.mutedForeground,
                        ),
                        onPressed: onClear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                filled: true,
                fillColor: AppColors.card,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: AppDimens.border,
                  ),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: AppDimens.border,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: AppDimens.borderThick,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: canSearch ? AppColors.primary : AppColors.muted,
            child: InkWell(
              onTap: canSearch ? onSearchTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'SEARCH',
                  style: AppTextStyles.display(
                    12,
                    color: canSearch
                        ? AppColors.primaryForeground
                        : AppColors.mutedForeground,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.results,
    required this.loadingMore,
    required this.scrollController,
    required this.resultCount,
    required this.hasMore,
  });

  final String query;
  final List<ExploreEvent> results;
  final bool loadingMore;
  final ScrollController scrollController;
  final int resultCount;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const _SearchIdle();

    if (results.isEmpty) {
      return const _SearchEmpty();
    }

    return CustomScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _ResultsHeader(count: resultCount, hasMore: hasMore),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: ExploreEventTileLayout.crossAxisCount,
            crossAxisSpacing: ExploreEventTileLayout.gridSpacing,
            mainAxisSpacing: ExploreEventTileLayout.gridSpacing,
            childCount: results.length,
            itemBuilder: (context, index) => RepaintBoundary(
              child: ExploreEventTile(event: results[index]),
            ),
          ),
        ),
        if (loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.hasMore});

  final int count;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final label = hasMore && count > 0
        ? '$count+ EVENTS'
        : count == 1
        ? '1 EVENT'
        : '$count EVENTS';

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
          const Icon(Icons.bolt_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.display(
              18,
              color: AppColors.secondary,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchIdle extends StatelessWidget {
  const _SearchIdle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.55),
                border: Border.all(
                  color: AppColors.border,
                  width: AppDimens.border,
                ),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 44,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'SEARCH FOR EVENTS',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(
                22,
                color: AppColors.secondary,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Event name, venue, city, area, state, postal code,\ndate (e.g. 22 June 2026), or description',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                14,
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.muted,
            ),
            const SizedBox(height: 20),
            Text(
              'NO EVENTS FOUND',
              style: AppTextStyles.display(
                20,
                color: AppColors.secondary,
                letterSpacing: 0.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Try another city, area, venue, date, or keyword\nin the title or description',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                14,
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLoadingGrid extends StatelessWidget {
  const _SearchLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SEARCHING…',
                style: AppTextStyles.display(
                  18,
                  color: AppColors.secondary,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: ExploreEventTileLayout.crossAxisCount,
            crossAxisSpacing: ExploreEventTileLayout.gridSpacing,
            mainAxisSpacing: ExploreEventTileLayout.gridSpacing,
            itemCount: 6,
            itemBuilder: (_, index) => _ExploreTileSkeleton(
              animate: true,
              tall: index.isOdd,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreTileSkeleton extends StatefulWidget {
  const _ExploreTileSkeleton({required this.animate, this.tall = false});

  final bool animate;
  final bool tall;

  @override
  State<_ExploreTileSkeleton> createState() => _ExploreTileSkeletonState();
}

class _ExploreTileSkeletonState extends State<_ExploreTileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = Tween<double>(
      begin: 0.42,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final opacity = widget.animate ? _pulse.value : 0.55;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: ColoredBox(
                  color: AppColors.muted.withValues(alpha: opacity),
                  child: SizedBox(height: widget.tall ? 150 : 120),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(
                      width: double.infinity,
                      height: 14,
                      opacity: opacity,
                    ),
                    const SizedBox(height: 8),
                    _Bone(width: 96, height: 10, opacity: opacity),
                    if (widget.tall) ...[
                      const SizedBox(height: 8),
                      _Bone(width: 72, height: 10, opacity: opacity),
                    ],
                    const SizedBox(height: 12),
                    _Bone(
                      width: double.infinity,
                      height: ExploreEventTileLayout.calendarHeight,
                      opacity: opacity,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(color: AppColors.muted.withValues(alpha: opacity)),
    );
  }
}
