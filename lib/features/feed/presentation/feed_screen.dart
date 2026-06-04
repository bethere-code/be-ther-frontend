import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_images.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/post_interaction_row.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../../core/utils/link_utils.dart';
import '../../../core/utils/post_author.dart';
import '../../profile/presentation/profile_screen.dart';
import 'add_post_screen.dart';
import 'feed_providers.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  static const path = '/feed';
  static const name = 'feed';

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late ScrollController _scrollController;
  List<Map<String, dynamic>> _allItems = [];
  int _currentSkip = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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

    const feedHeaderHeight = kToolbarHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AppShell(
        activeTab: ShellTab.home,
        header: PreferredSize(
          preferredSize: const Size.fromHeight(feedHeaderHeight),
          child: Container(
            height: feedHeaderHeight,
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(ProfileScreen.path),
                    child: Image.asset(
                      AppImages.beatherLogo,
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
              if (_currentSkip == 0 && _allItems.isEmpty) {
                _allItems = page.items;
                _hasMore = page.nextSkip != null;
              } else if (_currentSkip > 0) {
                _allItems.addAll(page.items);
                _hasMore = page.nextSkip != null;
              }

              if (mounted && _isLoadingMore) {
                setState(() => _isLoadingMore = false);
              }

              if (_allItems.isEmpty) {
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
                  itemCount: _allItems.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _allItems.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final item = _allItems[index];
                    return RepaintBoundary(child: _FeedCard(item: item));
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

class _FeedCard extends ConsumerStatefulWidget {
  const _FeedCard({required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<_FeedCard> {
  late bool _inCalendar;
  bool _isCalendarLoading = false;
  String? _calendarError;

  @override
  void initState() {
    super.initState();
    _syncCalendarFromItem();
  }

  @override
  void didUpdateWidget(covariant _FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['inCalendar'] != widget.item['inCalendar']) {
      _syncCalendarFromItem();
    }
  }

  void _syncCalendarFromItem() {
    _inCalendar = widget.item['inCalendar'] as bool? ?? false;
  }

  Future<void> _handleCalendarToggle(String postId) async {
    if (postId.isEmpty || _isCalendarLoading) return;

    setState(() {
      _isCalendarLoading = true;
      _calendarError = null;
    });

    try {
      final inCalendar = await ref
          .read(postsRepositoryProvider)
          .toggleCalendar(postId);
      if (mounted) {
        setState(() => _inCalendar = inCalendar);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calendarError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCalendarLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final author = readPostAuthor(item);
    final name =
        author['displayName'] as String? ??
        author['username'] as String? ??
        'User';
    final username = author['username'] as String? ?? '';
    final avatar = author['avatarUrl'] as String? ?? '';
    final badge = postAuthorBadge(item);
    final liked = item['liked'] as bool? ?? false;
    final location = item['location'] as String? ?? '';
    final country = item['country'] as String? ?? '';
    final status = item['status'] as String? ?? 'going';
    final imageUrl = item['imageUrl'] as String? ?? '';
    final caption = item['caption'] as String? ?? '';
    final likes = item['likesCount'] as int? ?? 0;
    final comments = item['commentsCount'] as int? ?? 0;
    final id = item['_id']?.toString() ?? '';
    final details = item['eventDetails'] as Map<String, dynamic>?;
    final ticketUrl = details?['ticketUrl'] as String?;
    final createdAt = item['createdAt'] as String?;
    final timestamp = createdAt != null
        ? DateTime.parse(createdAt)
        : DateTime.now();
    final relativeTime = getRelativeTime(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: username.isEmpty
                          ? null
                          : () => context.push(
                              ProfileScreen.pathForUser(username),
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.body(
                              15,
                              weight: FontWeight.w800,
                            ),
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
            aspectRatio: 21 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BeTherNetworkImage(url: imageUrl, fit: BoxFit.contain),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    color: AppColors.secondary.withValues(alpha: 0.9),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place,
                          color: AppColors.background,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          country,
                          style: AppTextStyles.display(
                            12,
                            color: AppColors.background,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.body(15),
                children: [
                  // TextSpan(
                  //   text: '$name ',
                  //   style: AppTextStyles.body(15, weight: FontWeight.w800),
                  // ),
                  TextSpan(text: caption),
                ],
              ),
            ),
          ),
          if (details != null && details.isNotEmpty)
            _EventDetails(
              details,
              ticketUrl: ticketUrl,
              inCalendar: _inCalendar,
              isLoading: _isCalendarLoading,
              error: _calendarError,
              onCalendarToggle: () => _handleCalendarToggle(id),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: AppDimens.borderThin,
                ),
              ),
            ),
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

class _EventDetails extends StatelessWidget {
  const _EventDetails(
    this.details, {
    this.ticketUrl,
    this.inCalendar = false,
    this.isLoading = false,
    this.error,
    this.onCalendarToggle,
  });

  final Map<String, dynamic> details;
  final String? ticketUrl;
  final bool inCalendar;
  final bool isLoading;
  final String? error;
  final VoidCallback? onCalendarToggle;

  static String? _formatDisplayDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.length >= 10) {
      final iso = DateTime.tryParse(trimmed.substring(0, 10));
      if (iso != null) return DateFormat('d MMM y').format(iso);
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return DateFormat('d MMM y').format(parsed);
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final dateRaw = details['date'] as String?;
    final time = details['time'] as String?;
    final venue = details['venue'] as String?;
    final displayDate = _formatDisplayDate(dateRaw);
    final displayTime = time?.trim();
    final displayVenue = venue?.trim();
    final hasMeta = displayDate != null ||
        (displayTime != null && displayTime.isNotEmpty) ||
        (displayVenue != null && displayVenue.isNotEmpty);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: AppDimens.borderThin),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMeta)
            Wrap(
              spacing: 20,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (displayDate != null)
                  _EventDetailMeta(
                    icon: Icons.calendar_today_outlined,
                    label: displayDate,
                  ),
                if (displayTime != null && displayTime.isNotEmpty)
                  _EventDetailMeta(
                    icon: Icons.schedule_outlined,
                    label: displayTime,
                  ),
                if (displayVenue != null && displayVenue.isNotEmpty)
                  _EventDetailMeta(
                    icon: Icons.place_outlined,
                    label: displayVenue,
                  ),
              ],
            ),
          if (hasMeta) const SizedBox(height: 12),
          if (ticketUrl != null && ticketUrl!.trim().isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => openExternalUrl(context, ticketUrl),
                child: Text(
                  'GET TICKETS',
                  style: AppTextStyles.display(14, color: AppColors.secondary),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: inCalendar
                    ? AppColors.primary
                    : AppColors.accent,
                foregroundColor: inCalendar
                    ? AppColors.primaryForeground
                    : AppColors.accentForeground,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: isLoading ? null : onCalendarToggle,
              child: Text(
                inCalendar ? 'ADDED TO CALENDAR' : 'ADD TO CALENDAR',
                style: AppTextStyles.display(
                  14,
                  color: inCalendar
                      ? AppColors.primaryForeground
                      : AppColors.accentForeground,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: AppTextStyles.body(12, color: AppColors.destructive),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventDetailMeta extends StatelessWidget {
  const _EventDetailMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            style: AppTextStyles.body(
              13,
              color: AppColors.secondary,
              weight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
