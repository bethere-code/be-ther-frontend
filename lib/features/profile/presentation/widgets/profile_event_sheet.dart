import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/design/widgets/post_more_menu_button.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../explore/domain/explore_event.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../profile/presentation/profile_screen.dart';

class ProfileCalendarEvent {
  const ProfileCalendarEvent({
    required this.postId,
    required this.date,
    required this.location,
    required this.imageUrl,
    required this.status,
    required this.venue,
    this.ticketUrl,
    this.time,
    this.country,
    this.place,
    this.author,
    this.bookmarked = false,
    this.source = 'authored',
    this.isAuthoredByMe = false,
    this.inCalendar = false,
    this.hiddenOnProfile = false,
  });

  final String postId;
  final DateTime date;
  final String location;
  final String imageUrl;
  final String status;
  final String venue;
  final String? ticketUrl;
  final String? time;
  final String? country;
  final String? place;
  final ExploreAuthor? author;
  final bool bookmarked;
  final String source;
  final bool isAuthoredByMe;
  final bool inCalendar;
  final bool hiddenOnProfile;

  String get title => location;

  /// Place for chips / rows (deduped against title).
  String get placeLabel {
    final candidates = <String>[
      place?.trim() ?? '',
      country?.trim() ?? '',
      venue.trim(),
    ];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      if (title.isNotEmpty && c.toLowerCase() == title.toLowerCase()) continue;
      return c;
    }
    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }
    return '';
  }

  String get formattedDate => DateFormat('MMM d, y').format(date);

  bool get hasTicketUrl =>
      !isPast && ticketUrl != null && ticketUrl!.trim().isNotEmpty;

  factory ProfileCalendarEvent.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    return ProfileCalendarEvent(
      postId: json['postId']?.toString() ?? '',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      location: json['location'] as String? ?? json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'going',
      venue: json['venue'] as String? ?? '',
      ticketUrl: json['ticketUrl'] as String?,
      time: json['time'] as String?,
      country: json['country'] as String?,
      place: json['place'] as String?,
      author: ExploreAuthor.tryParse(json['authorId'] ?? json['author']),
      bookmarked: json['bookmarked'] as bool? ?? false,
      source: json['source'] as String? ?? 'authored',
      isAuthoredByMe: json['isAuthoredByMe'] as bool? ?? false,
      inCalendar: json['inCalendar'] as bool? ?? false,
      hiddenOnProfile: json['hiddenOnProfile'] as bool? ?? false,
    );
  }

  ProfileCalendarEvent copyWith({bool? bookmarked, bool? inCalendar}) {
    return ProfileCalendarEvent(
      postId: postId,
      date: date,
      location: location,
      imageUrl: imageUrl,
      status: status,
      venue: venue,
      ticketUrl: ticketUrl,
      time: time,
      country: country,
      place: place,
      author: author,
      bookmarked: bookmarked ?? this.bookmarked,
      source: source,
      isAuthoredByMe: isAuthoredByMe,
      inCalendar: inCalendar ?? this.inCalendar,
      hiddenOnProfile: hiddenOnProfile,
    );
  }

  bool get isPast =>
      EventDateUtils.isEventPastFromDateTime(date, timeRaw: time);

  bool get canMarkNotGoing =>
      !isPast && (inCalendar || (isAuthoredByMe && status == 'going'));
}

Future<void> showProfileEventSheet({
  required BuildContext context,
  required ProfileCalendarEvent event,
  required String profileUsername,
  required bool showWishlist,
  required bool isOwnProfile,
  required Future<bool> Function() onToggleWishlist,
  required VoidCallback onCalendarChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.secondary.withValues(alpha: 0.45),
    builder: (context) => _ProfileEventSheet(
      event: event,
      profileUsername: profileUsername,
      showWishlist: showWishlist,
      isOwnProfile: isOwnProfile,
      onToggleWishlist: onToggleWishlist,
      onCalendarChanged: onCalendarChanged,
    ),
  );
}

class _ProfileEventSheet extends ConsumerStatefulWidget {
  const _ProfileEventSheet({
    required this.event,
    required this.profileUsername,
    required this.showWishlist,
    required this.isOwnProfile,
    required this.onToggleWishlist,
    required this.onCalendarChanged,
  });

  final ProfileCalendarEvent event;
  final String profileUsername;
  final bool showWishlist;
  final bool isOwnProfile;
  final Future<bool> Function() onToggleWishlist;
  final VoidCallback onCalendarChanged;

  @override
  ConsumerState<_ProfileEventSheet> createState() => _ProfileEventSheetState();
}

class _ProfileEventSheetState extends ConsumerState<_ProfileEventSheet> {
  late bool _bookmarked;
  late bool _inCalendar;
  bool _busy = false;

  ProfileCalendarEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _bookmarked = event.bookmarked;
    _inCalendar = event.inCalendar;
  }

  /// Owner differs from the profile calendar we're browsing.
  bool get _showOwnerRow {
    final author = event.author;
    if (author == null || author.username.isEmpty) return false;
    return author.username.toLowerCase() !=
        widget.profileUsername.toLowerCase();
  }

  String get _headerLabel {
    if (_showOwnerRow) return '@${event.author!.username}';
    return 'EVENT DETAILS';
  }

  Future<void> _toggleWishlist() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onToggleWishlist();
      if (mounted) setState(() => _bookmarked = saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleCalendar() async {
    if (event.postId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final next =
          await ref.read(postsRepositoryProvider).toggleCalendar(event.postId);
      if (!mounted) return;
      setState(() => _inCalendar = next);
      widget.onCalendarChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onCalendarChanged();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'DELETE EVENT?',
          style: AppTextStyles.display(20, color: AppColors.secondary),
        ),
        content: Text(
          'This permanently removes the event and cannot be undone.',
          style: AppTextStyles.body(15, color: AppColors.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(
      () => ref.read(postsRepositoryProvider).deletePost(event.postId),
      success: 'Event deleted',
    );
  }

  Future<void> _hideEvent() async {
    await _runAction(
      () => ref.read(postsRepositoryProvider).hideOnProfile(event.postId),
      success: 'Hidden from your public profile',
    );
  }

  Future<void> _notGoing() async {
    await _runAction(
      () => ref.read(postsRepositoryProvider).markNotGoing(event.postId),
      success: 'Removed from your calendar',
    );
  }

  void _openOwnerProfile() {
    final username = event.author?.username ?? '';
    if (username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(username));
  }

  @override
  Widget build(BuildContext context) {
    final place = event.placeLabel;
    final timeLabel = event.time?.trim();
    final author = event.author;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.background,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: AppDimens.borderThick,
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedForeground.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _headerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(
                          20,
                          color: AppColors.primary,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ),
                    if (widget.isOwnProfile)
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        padding: EdgeInsets.zero,
                        offset: const Offset(0, 8),
                        color: AppColors.card,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(
                            color: AppColors.border,
                            width: AppDimens.border,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: PostMoreMenuIcon(),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'hide':
                              _hideEvent();
                            case 'delete':
                              _confirmDelete();
                            case 'not_going':
                              _notGoing();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'hide',
                            enabled: !event.hiddenOnProfile,
                            child: Text(
                              event.hiddenOnProfile
                                  ? 'Already hidden'
                                  : 'Hide event',
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (event.isAuthoredByMe)
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete event',
                                style: AppTextStyles.body(
                                  14,
                                  weight: FontWeight.w700,
                                  color: AppColors.destructive,
                                ),
                              ),
                            ),
                          if (event.canMarkNotGoing)
                            PopupMenuItem(
                              value: 'not_going',
                              child: Text(
                                'Not going',
                                style: AppTextStyles.body(
                                  14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.secondary,
                          size: 26,
                        ),
                      ),
                  ],
                ),
                if (event.imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Material(
                      color: AppColors.card,
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BeTherNetworkImage(
                            url: event.imageUrl,
                            fit: BoxFit.cover,
                          ),
                          if (place.isNotEmpty)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                color: AppColors.secondary.withValues(
                                  alpha: 0.9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.place,
                                      size: 14,
                                      color: AppColors.background,
                                    ),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        place.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.display(
                                          12,
                                          color: AppColors.background,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (event.hiddenOnProfile)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                color: AppColors.secondary.withValues(
                                  alpha: 0.85,
                                ),
                                child: Text(
                                  'HIDDEN ON PROFILE',
                                  style: AppTextStyles.display(
                                    10,
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  event.title,
                  style: AppTextStyles.display(24, color: AppColors.secondary),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.55),
                    border: Border.all(
                      color: AppColors.border,
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: event.formattedDate,
                          ),
                          if (timeLabel != null && timeLabel.isNotEmpty)
                            _MetaChip(
                              icon: Icons.access_time,
                              label: timeLabel,
                            ),
                        ],
                      ),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: place,
                          expanded: true,
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (event.isPast)
                        Container(
                          width: double.infinity,
                          height: 44,
                          alignment: Alignment.center,
                          color: AppColors.muted,
                          child: Text(
                            'PAST EVENT',
                            style: AppTextStyles.display(
                              14,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        )
                      else if (widget.showWishlist)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _bookmarked
                                  ? AppColors.primary
                                  : AppColors.accent,
                              foregroundColor: _bookmarked
                                  ? AppColors.primaryForeground
                                  : AppColors.accentForeground,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _busy ? null : _toggleWishlist,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _bookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 18,
                                  color: _bookmarked
                                      ? AppColors.primaryForeground
                                      : AppColors.accentForeground,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _bookmarked ? 'SAVED' : 'ADD TO WISHLIST',
                                  style: AppTextStyles.display(
                                    14,
                                    color: _bookmarked
                                        ? AppColors.primaryForeground
                                        : AppColors.accentForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _inCalendar
                                  ? AppColors.primary
                                  : AppColors.accent,
                              foregroundColor: _inCalendar
                                  ? AppColors.primaryForeground
                                  : AppColors.accentForeground,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _busy ? null : _toggleCalendar,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentForeground,
                                    ),
                                  )
                                : Text(
                                    _inCalendar
                                        ? 'ADDED TO CALENDAR'
                                        : 'ADD TO CALENDAR',
                                    style: AppTextStyles.display(
                                      14,
                                      color: _inCalendar
                                          ? AppColors.primaryForeground
                                          : AppColors.accentForeground,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_showOwnerRow && author != null) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.card,
                    child: InkWell(
                      onTap: _openOwnerProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.border,
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Row(
                          children: [
                            AuthorAvatar(
                              avatarUrl: author.avatarUrl,
                              username: author.username,
                              badge: author.badge,
                              size: 44,
                              interactive: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(
                                      15,
                                      weight: FontWeight.w700,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${author.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(
                                      13,
                                      weight: FontWeight.w600,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (event.hasTicketUrl)
                      IconButton(
                        tooltip: 'Open tickets',
                        onPressed: () =>
                            openExternalUrl(context, event.ticketUrl!),
                        icon: const Icon(Icons.link),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: event.postId.isEmpty
                          ? null
                          : () async {
                              try {
                                await sharePostContent(
                                  postId: event.postId,
                                  location: event.title,
                                  imageUrl: event.imageUrl,
                                  ticketUrl: event.ticketUrl,
                                  venue: place.isEmpty ? null : place,
                                  date: event.formattedDate,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: expanded ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              13.5,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
