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
import '../../../core/utils/post_author.dart';
import '../../../core/utils/time_utils.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const path = '/search';
  static const name = 'search';

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  int _currentSkip = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _allResults = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_searchController.text.trim().isEmpty || _isLoadingMore || !_hasMore) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _currentSkip += 10;
    });
  }

  void _performSearch() {
    setState(() {
      _allResults.clear();
      _currentSkip = 0;
      _isLoadingMore = false;
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    final searchResults = ref.watch(
      searchResultsProvider((query: query, country: null, skip: _currentSkip)),
    );

    return AppShell(
      activeTab: ShellTab.home,
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Container(
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
                        controller: _searchController,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Search locations...',
                          hintStyle: AppTextStyles.body(
                            14,
                            color: AppColors.mutedForeground,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.mutedForeground,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.mutedForeground,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _allResults.clear();
                                    _currentSkip = 0;
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: AppColors.border,
                              width: AppDimens.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: AppColors.border,
                              width: AppDimens.border,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                        onSubmitted: (_) {
                          _performSearch();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _searchController.text.isNotEmpty
                          ? AppColors.primary
                          : AppColors.muted,
                      child: InkWell(
                        onTap: _searchController.text.isNotEmpty
                            ? _performSearch
                            : null,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'SEARCH',
                            style: AppTextStyles.display(
                              13,
                              color: _searchController.text.isNotEmpty
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
            ),
            Expanded(
              child: searchResults.when(
                data: (result) {
                  if (_currentSkip == 0) {
                    _allResults = result.items;
                  } else {
                    _allResults.addAll(result.items);
                  }
                  _hasMore = result.nextSkip != null;
                  if (mounted && _isLoadingMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isLoadingMore = false);
                    });
                  }

                  if (_allResults.isEmpty &&
                      _searchController.text.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 48,
                              color: AppColors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: AppTextStyles.display(
                                18,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
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
                    controller: _scrollController,
                    itemCount:
                        _allResults.length +
                        (_isLoadingMore && _hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _allResults.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        );
                      }
                      final item = _allResults[index];
                      return RepaintBoundary(
                        child: _SearchResultCard(item: item),
                      );
                    },
                  );
                },
                loading: () => _searchController.text.isNotEmpty
                    ? ListView.builder(
                        itemCount: 5,
                        itemBuilder: (context, index) => const PostSkeleton(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 48,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Search for events',
                                style: AppTextStyles.display(
                                  18,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter a location above to discover events',
                                style: AppTextStyles.body(
                                  14,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final author = readPostAuthor(item);
    final name =
        author['displayName'] as String? ??
        author['username'] as String? ??
        'User';
    final username = author['username'] as String? ?? '';
    final avatar = author['avatarUrl'] as String? ?? '';
    final badge = postAuthorBadge(item);
    final location = item['location'] as String? ?? '';
    final status = item['status'] as String? ?? 'going';
    final caption = item['caption'] as String? ?? '';
    final likes = item['likesCount'] as int? ?? 0;
    final comments = item['commentsCount'] as int? ?? 0;
    final imageUrl = item['imageUrl'] as String? ?? '';
    final id = item['_id']?.toString() ?? '';
    final liked = item['liked'] as bool? ?? false;
    final details = item['eventDetails'] as Map<String, dynamic>?;
    final ticketUrl = details?['ticketUrl'] as String?;
    final createdAt = item['createdAt'] as String?;
    final timestamp = DateTime.tryParse(createdAt ?? '') ?? DateTime.now();
    final relativeTime = getRelativeTime(timestamp);

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
                  avatarUrl: avatar,
                  username: username,
                  badge: badge,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
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
                    color: status == 'been'
                        ? AppColors.primary
                        : status == 'going'
                        ? AppColors.accent
                        : AppColors.muted,
                    border: Border.all(
                      color: AppColors.border,
                      width: AppDimens.border,
                    ),
                  ),
                  child: Text(
                    status == 'been'
                        ? 'BEEN'
                        : status == 'going'
                        ? 'GOING'
                        : 'INTERESTED',
                    style: AppTextStyles.display(
                      14,
                      color: status == 'been'
                          ? AppColors.primaryForeground
                          : status == 'going'
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
            child: imageUrl.isNotEmpty
                ? BeTherNetworkImage(url: imageUrl, fit: BoxFit.cover)
                : Container(color: AppColors.muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              location,
              style: AppTextStyles.display(
                22,
                color: AppColors.secondary,
                letterSpacing: 0.02,
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                caption,
                style: AppTextStyles.body(15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: PostInteractionRow(
              postId: id,
              liked: liked,
              likesCount: likes,
              commentsCount: comments,
              location: location,
              caption: caption,
              ticketUrl: ticketUrl,
            ),
          ),
        ],
      ),
    );
  }
}
