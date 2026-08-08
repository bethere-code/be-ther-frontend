import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/design/widgets/expandable_caption.dart';
import '../../../../core/design/widgets/post_more_menu_button.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../explore/domain/explore_event.dart';
import '../../../feed/presentation/calendar_status_store.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../feed/presentation/widgets/calendar_rsvp_sheet.dart';
import '../../../feed/presentation/widgets/feed_attendees_sheet.dart';
import '../../../feed/presentation/widgets/feed_comments_sheet.dart';
import '../../../feed/presentation/widgets/feed_likes_sheet.dart';
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
    this.address,
    this.calendarCount = 0,
    this.viewCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.author,
    this.bookmarked = false,
    this.source = 'authored',
    this.isAuthoredByMe = false,
    this.inCalendar = false,
    this.calendarStatus,
    this.hiddenOnProfile = false,
    this.caption,
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
  /// Full venue / Places address when available.
  final String? address;
  final int calendarCount;
  final int viewCount;
  final int likesCount;
  final int commentsCount;
  final ExploreAuthor? author;
  final bool bookmarked;
  final String source;
  final bool isAuthoredByMe;
  final bool inCalendar;
  final String? calendarStatus;
  final bool hiddenOnProfile;
  final String? caption;

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

  /// Prefer full address for detail sheets; fall back to place chip label.
  String get fullLocationLabel {
    final full = address?.trim() ?? '';
    if (full.isNotEmpty) return full;
    final venueLabel = venue.trim();
    if (venueLabel.isNotEmpty &&
        venueLabel.toLowerCase() != title.toLowerCase()) {
      return venueLabel;
    }
    return placeLabel;
  }

  String get formattedDate => DateFormat('MMM d, y').format(date);

  /// `HH:mm` / already-localized → `h:mm AM/PM`.
  String? get formattedTime {
    final raw = time?.trim();
    if (raw == null || raw.isEmpty) return null;

    final twelve = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(raw);
    if (twelve != null) {
      var hour = int.parse(twelve.group(1)!);
      final minute = twelve.group(2)!;
      final period = twelve.group(3)!.toUpperCase();
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (twentyFour != null) {
      var hour = int.parse(twentyFour.group(1)!);
      final minute = twentyFour.group(2)!;
      if (hour < 0 || hour > 23) return raw;
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    return raw;
  }

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
      address: json['address'] as String?,
      calendarCount: (json['calendarCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      author: ExploreAuthor.tryParse(json['authorId'] ?? json['author']),
      bookmarked: json['bookmarked'] as bool? ?? false,
      source: json['source'] as String? ?? 'authored',
      isAuthoredByMe: json['isAuthoredByMe'] as bool? ?? false,
      inCalendar: json['inCalendar'] as bool? ?? false,
      calendarStatus: json['calendarStatus'] as String? ??
          ((json['inCalendar'] as bool? ?? false) ? 'going' : null),
      hiddenOnProfile: json['hiddenOnProfile'] as bool? ?? false,
      caption: (json['caption'] as String?)?.trim().isNotEmpty == true
          ? (json['caption'] as String).trim()
          : null,
    );
  }

  ProfileCalendarEvent copyWith({
    bool? bookmarked,
    bool? inCalendar,
    String? calendarStatus,
    int? likesCount,
    int? commentsCount,
  }) {
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
      address: address,
      calendarCount: calendarCount,
      viewCount: viewCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      author: author,
      bookmarked: bookmarked ?? this.bookmarked,
      source: source,
      isAuthoredByMe: isAuthoredByMe,
      inCalendar: inCalendar ?? this.inCalendar,
      calendarStatus: calendarStatus ?? this.calendarStatus,
      hiddenOnProfile: hiddenOnProfile,
      caption: caption,
    );
  }

  bool get isPast =>
      EventDateUtils.isEventPastFromDateTime(date, timeRaw: time);

  bool get canMarkNotGoing =>
      !isPast && inCalendar && !isAuthoredByMe;
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
  String? _calendarStatus;
  bool _busy = false;
  late int _likesCount;
  late int _commentsCount;

  /// One-shot attendees load for own events (no polling / no repeat calls).
  List<Map<String, dynamic>> _goingPeople = const [];
  int _goingCount = 0;
  bool _goingLoading = false;
  bool _goingLoaded = false;

  ProfileCalendarEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _bookmarked = event.bookmarked;
    _likesCount = event.likesCount;
    _commentsCount = event.commentsCount;
    final fromStore = ref
        .read(calendarStatusStoreProvider.notifier)
        .statusFor(
          event.postId,
          fallback: event.calendarStatus ??
              (event.isAuthoredByMe
                  ? (event.status == 'interested' ? 'interested' : 'going')
                  : (event.inCalendar ? 'going' : null)),
        );
    _calendarStatus = fromStore;
    _inCalendar = event.isAuthoredByMe || _calendarStatus != null;
    _goingCount = event.calendarCount;
    if (event.isAuthoredByMe && event.postId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadGoingOnce();
      });
    }
  }

  Future<void> _loadGoingOnce() async {
    if (_goingLoaded || _goingLoading || event.postId.isEmpty) return;
    setState(() => _goingLoading = true);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .fetchAttendees(postId: event.postId, skip: 0);
      if (!mounted) return;
      setState(() {
        _goingPeople = page.items;
        _goingCount = page.total;
        _goingLoading = false;
        _goingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _goingLoading = false;
        _goingLoaded = true;
        // Keep calendarCount from the event if the list call fails.
        _goingCount = event.calendarCount;
        _goingPeople = const [];
      });
    }
  }

  void _openGoingPerson(Map<String, dynamic> user) {
    final username = (user['username'] as String?)?.trim() ?? '';
    if (username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(username));
  }

  void _openGoingList() {
    if (event.postId.isEmpty || _goingCount < 1) return;
    showFeedAttendeesSheet(
      context: context,
      postId: event.postId,
      initialCount: _goingCount,
    );
  }

  void _openLikes() {
    if (event.postId.isEmpty || _likesCount <= 0) return;
    showFeedLikesSheet(
      context: context,
      postId: event.postId,
      initialCount: _likesCount,
    );
  }

  void _openComments() {
    if (event.postId.isEmpty) return;
    showFeedCommentsSheet(
      context: context,
      postId: event.postId,
      initialCount: _commentsCount,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() => _commentsCount = count);
      },
    );
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
    // Authors cannot remove their own event — only switch Interested ↔ Going.
    if (event.isAuthoredByMe) {
      await _setOwnerStatus();
      return;
    }
    final choice = await showCalendarRsvpSheet(
      context: context,
      alreadyOnCalendar: _inCalendar,
      currentStatus: _calendarStatus,
    );
    if (choice == null || !mounted) return;

    final status = switch (choice) {
      CalendarRsvpChoice.interested => 'interested',
      CalendarRsvpChoice.going => 'going',
      CalendarRsvpChoice.none => 'none',
    };

    setState(() => _busy = true);
    try {
      final data = await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: event.postId, status: status);
      final cleared = status == 'none';
      final nextStatus = cleared ? null : data['calendarStatus'] as String?;
      final inCalendar = cleared
          ? false
          : (data['inCalendar'] as bool? ?? (nextStatus != null));
      final resolved = inCalendar ? (nextStatus ?? status) : null;
      ref
          .read(calendarStatusStoreProvider.notifier)
          .setStatus(event.postId, resolved);
      if (!mounted) return;
      setState(() {
        _calendarStatus = resolved;
        _inCalendar = resolved != null;
      });
      widget.onCalendarChanged();
      // Removed from calendar — leave the sheet so the day cell refreshes.
      if (cleared && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setOwnerStatus() async {
    final choice = await showCalendarRsvpSheet(
      context: context,
      alreadyOnCalendar: true,
      currentStatus: _calendarStatus ?? 'going',
      allowRemove: false,
    );
    if (choice == null || !mounted) return;
    if (choice == CalendarRsvpChoice.none) return;

    final status = choice == CalendarRsvpChoice.interested
        ? 'interested'
        : 'going';
    if (status == _calendarStatus) return;

    setState(() => _busy = true);
    try {
      final data = await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: event.postId, status: status);
      final nextStatus = data['calendarStatus'] as String? ?? status;
      ref
          .read(calendarStatusStoreProvider.notifier)
          .setStatus(event.postId, nextStatus);
      if (!mounted) return;
      setState(() {
        _calendarStatus = nextStatus;
        _inCalendar = true;
      });
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
    if (event.postId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: event.postId, status: 'none');
      ref.read(calendarStatusStoreProvider.notifier).setStatus(event.postId, null);
      if (!mounted) return;
      widget.onCalendarChanged();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from your calendar')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final fullLocation = event.fullLocationLabel;
    final timeLabel = event.formattedTime;
    final author = event.author;
    final showOwnInsights = event.isAuthoredByMe;
    final showGoingRow = showOwnInsights && _goingCount >= 1;
    final showViewsRow = showOwnInsights && event.viewCount > 0;
    final showOwnerStatusToggle =
        widget.isOwnProfile && event.isAuthoredByMe && !event.isPast;
    final showStatusButton = !event.isAuthoredByMe &&
        !event.isPast &&
        _inCalendar &&
        (widget.isOwnProfile || !widget.showWishlist);
    final caption = event.caption?.trim() ?? '';
    final locationForShare =
        fullLocation.isNotEmpty ? fullLocation : (place.isEmpty ? null : place);

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
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpandableCaption(
                    key: ValueKey('profile-caption-${event.postId}'),
                    text: caption,
                    trimLines: 2,
                  ),
                ],
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
                      if (fullLocation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: fullLocation,
                          expanded: true,
                          maxLines: 3,
                        ),
                      ],
                      if (showViewsRow) ...[
                        const SizedBox(height: 12),
                        _MetaChip(
                          icon: Icons.visibility_outlined,
                          label: event.viewCount == 1
                              ? '1 view'
                              : '${event.viewCount} views',
                          expanded: true,
                          maxLines: 1,
                        ),
                      ],
                      if (showGoingRow) ...[
                        const SizedBox(height: 14),
                        _GoingInsightRow(
                          count: _goingCount,
                          people: _goingPeople,
                          loading: _goingLoading,
                          onOpenList: _openGoingList,
                          onOpenPerson: _openGoingPerson,
                        ),
                      ],
                      if (showOwnerStatusToggle) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  calendarButtonBackground(_calendarStatus),
                              foregroundColor:
                                  calendarButtonForeground(_calendarStatus),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _busy ? null : _setOwnerStatus,
                            child: _busy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
                                    ),
                                  )
                                : Text(
                                    calendarButtonLabel(_calendarStatus),
                                    style: AppTextStyles.display(
                                      14,
                                      color: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to switch Interested or Going. Delete the event to remove it.',
                          style: AppTextStyles.body(
                            12,
                            color: AppColors.mutedForeground,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (event.isPast) ...[
                        const SizedBox(height: 12),
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
                        ),
                      ] else if (widget.showWishlist) ...[
                        const SizedBox(height: 12),
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
                        ),
                      ] else if (showStatusButton ||
                          (!showOwnInsights && !_inCalendar)) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  calendarButtonBackground(_calendarStatus),
                              foregroundColor:
                                  calendarButtonForeground(_calendarStatus),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _busy ? null : _toggleCalendar,
                            child: _busy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
                                    ),
                                  )
                                : Text(
                                    calendarButtonLabel(_calendarStatus),
                                    style: AppTextStyles.display(
                                      14,
                                      color: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (showStatusButton) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tap to change status or remove from your calendar.',
                            style: AppTextStyles.body(
                              12,
                              color: AppColors.mutedForeground,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
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
                    InkWell(
                      onTap: _likesCount > 0 ? _openLikes : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              size: 20,
                              color: AppColors.foreground,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_likesCount',
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: event.postId.isEmpty ? null : _openComments,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                              color: AppColors.foreground,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_commentsCount',
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                  venue: locationForShare,
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
    this.maxLines = 2,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.secondary),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: expanded ? maxLines : 1,
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

class _GoingInsightRow extends StatelessWidget {
  const _GoingInsightRow({
    required this.count,
    required this.people,
    required this.loading,
    required this.onOpenList,
    required this.onOpenPerson,
  });

  final int count;
  final List<Map<String, dynamic>> people;
  final bool loading;
  final VoidCallback onOpenList;
  final void Function(Map<String, dynamic> user) onOpenPerson;

  static const _maxFaces = 5;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 going' : '$count going';
    final faces = people.take(_maxFaces).toList(growable: false);
    final overflow = count > faces.length ? count - faces.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenList,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body(
                        13.5,
                        weight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (loading && faces.isEmpty) ...[
          const SizedBox(height: 10),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ] else if (faces.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                for (var i = 0; i < faces.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _GoingFace(
                    user: faces[i],
                    onTap: () => onOpenPerson(faces[i]),
                  ),
                ],
                if (overflow > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onOpenList,
                    child: Text(
                      '+$overflow',
                      style: AppTextStyles.body(
                        13,
                        weight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GoingFace extends StatelessWidget {
  const _GoingFace({required this.user, required this.onTap});

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final username = (user['username'] as String?)?.trim() ?? '';
    final avatar = (user['avatarUrl'] as String?) ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: username.isEmpty ? null : onTap,
        customBorder: const CircleBorder(),
        child: AuthorAvatar(
          avatarUrl: avatar,
          username: username,
          size: 36,
          interactive: false,
        ),
      ),
    );
  }
}
