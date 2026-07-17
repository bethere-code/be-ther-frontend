import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/post_interaction_row.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../../core/utils/time_utils.dart';
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
  Timer? _debounceTimer;

  final List<SearchPost> _results = [];
  int _skip = 0;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _activeQuery = '';
  String? _appliedKey;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    if (trimmed.isEmpty) {
      _commitQuery('');
      return;
    }
    _debounceTimer = Timer(_debounce, () => _commitQuery(trimmed));
    setState(() {}); // refresh clear / SEARCH button styling
  }

  void _commitQuery(String query) {
    _debounceTimer?.cancel();
    if (query == _activeQuery && _skip == 0) {
      // Same query — keep current results; SEARCH must not wipe the list.
      setState(() {});
      return;
    }
    setState(() {
      _activeQuery = query;
      _skip = 0;
      _loadingMore = false;
      _hasMore = true;
      _results.clear();
      _appliedKey = null;
    });
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    _commitQuery(_controller.text.trim());
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _controller.clear();
    _commitQuery('');
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
      '$_activeQuery|$_skip|${page.items.length}|${page.nextSkip}|${page.items.isEmpty ? '-' : page.items.first.id}';

  void _applyPage(SearchPage page) {
    if (!mounted) return;
    final key = _pageKey(page);
    if (key == _appliedKey) return;
    setState(() {
      _appliedKey = key;
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

  List<SearchPost> _displayItems(SearchPage page) {
    if (_skip == 0) return page.items;
    if (_results.isEmpty) return page.items;
    return List<SearchPost>.unmodifiable(_results);
  }

  @override
  Widget build(BuildContext context) {
    final params = (query: _activeQuery, skip: _skip);
    final asyncResults = ref.watch(searchResultsProvider(params));

    return AppShell(
      activeTab: ShellTab.home,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            _SearchHeader(
              controller: _controller,
              canSearch: _controller.text.trim().isNotEmpty,
              onChanged: _scheduleSearch,
              onSubmit: _submitSearch,
              onClear: _clearSearch,
              onSearchTap: _submitSearch,
            ),
            Expanded(
              child: asyncResults.when(
                data: (page) {
                  // Sync owned list after this frame (never mutate provider cache).
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _applyPage(page);
                  });
                  return _SearchBody(
                    query: _activeQuery,
                    results: _displayItems(page),
                    loadingMore: _loadingMore && _hasMore,
                    scrollController: _scrollController,
                  );
                },
                loading: () => _activeQuery.isEmpty
                    ? const _SearchIdle()
                    : _skip > 0 && _results.isNotEmpty
                        ? _SearchBody(
                            query: _activeQuery,
                            results: List<SearchPost>.unmodifiable(_results),
                            loadingMore: true,
                            scrollController: _scrollController,
                          )
                        : ListView.builder(
                            itemCount: 5,
                            itemBuilder: (_, _) => const PostSkeleton(),
                          ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      '$error',
                      style: AppTextStyles.body(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.canSearch,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final bool canSearch;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThick,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                style: AppTextStyles.body(15, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Event, venue, city, date, artist…',
                  hintStyle: AppTextStyles.body(
                    14,
                    color: AppColors.mutedForeground,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.mutedForeground,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
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
            const SizedBox(width: 8),
            Material(
              color: canSearch ? AppColors.primary : AppColors.muted,
              child: InkWell(
                onTap: canSearch ? onSearchTap : null,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'SEARCH',
                    style: AppTextStyles.display(
                      13,
                      color: canSearch
                          ? AppColors.primaryForeground
                          : AppColors.mutedForeground,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
  });

  final String query;
  final List<SearchPost> results;
  final bool loadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const _SearchIdle();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: AppTextStyles.display(18, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Try an event name, venue, city, date, or artist',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: results.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return RepaintBoundary(child: _SearchResultCard(post: results[index]));
      },
    );
  }
}

class _SearchIdle extends StatelessWidget {
  const _SearchIdle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              'Search for events',
              style: AppTextStyles.display(18, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Event name, venue, city, date (e.g. 22 June 2026),\ndescription, or artist',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.post});

  final SearchPost post;

  @override
  Widget build(BuildContext context) {
    final relativeTime = getRelativeTime(post.createdAt);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThick,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AuthorAvatar(
                  avatarUrl: post.avatarUrl,
                  username: post.username,
                  badge: post.badge,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.displayName,
                        style: AppTextStyles.body(15, weight: FontWeight.w800),
                      ),
                      Text(
                        relativeTime,
                        style: AppTextStyles.body(
                          12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: post.isPast
                        ? AppColors.muted
                        : post.status == 'been'
                            ? AppColors.primary
                            : post.status == 'going'
                                ? AppColors.accent
                                : AppColors.muted,
                    border: Border.all(
                      color: AppColors.border,
                      width: AppDimens.border,
                    ),
                  ),
                  child: Text(
                    post.statusLabel,
                    style: AppTextStyles.display(
                      14,
                      color: post.isPast
                          ? AppColors.mutedForeground
                          : post.status == 'been'
                              ? AppColors.primaryForeground
                              : post.status == 'going'
                                  ? AppColors.accentForeground
                                  : AppColors.foreground,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: post.imageUrl.isNotEmpty
                ? BeTherNetworkImage(url: post.imageUrl, fit: BoxFit.cover)
                : const ColoredBox(color: AppColors.muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              post.title,
              style: AppTextStyles.display(
                22,
                color: AppColors.secondary,
                letterSpacing: 0.02,
              ),
            ),
          ),
          if (post.city != null || post.venue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                [post.venue, post.city]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: AppTextStyles.body(
                  13,
                  color: AppColors.mutedForeground,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          if (post.caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                post.caption!,
                style: AppTextStyles.body(15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: PostInteractionRow(
              postId: post.id,
              liked: post.liked,
              likesCount: post.likesCount,
              commentsCount: post.commentsCount,
              location: post.title,
              caption: post.caption ?? '',
              ticketUrl: post.ticketUrl,
              imageUrl: post.imageUrl,
            ),
          ),
        ],
      ),
    );
  }
}
