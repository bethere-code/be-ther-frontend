import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/design/widgets/event_edited_badge.dart';
import '../../../../core/design/widgets/event_sheet_creator_row.dart';
import '../../../../core/design/widgets/expandable_caption.dart';
import '../../../../core/design/widgets/post_more_menu_button.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../explore/domain/explore_event.dart';
import '../../../feed/domain/feed_post.dart';
import '../../../explore/presentation/explore_providers.dart';
import '../../../feed/presentation/add_post_screen.dart';
import '../../../feed/presentation/calendar_status_store.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../feed/presentation/widgets/calendar_rsvp_sheet.dart';
import '../../../feed/presentation/widgets/feed_attendees_sheet.dart';
import '../../../feed/presentation/widgets/feed_comments_sheet.dart';
import '../../../feed/presentation/widgets/feed_likes_sheet.dart';
import '../../../feed/presentation/widgets/feed_post_more_menu.dart';
import '../../../notifications/presentation/notifications_providers.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../../profile/presentation/profile_screen.dart';
import 'package:be_ther/core/ui/app_toast.dart';

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
    this.editedAt,
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
  final DateTime? editedAt;

  bool get isEdited => editedAt != null;

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
  String? get formattedTime => EventDateUtils.formatTime12h(time);

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
      calendarStatus:
          json['calendarStatus'] as String? ??
          ((json['inCalendar'] as bool? ?? false) ? 'going' : null),
      hiddenOnProfile: json['hiddenOnProfile'] as bool? ?? false,
      caption: (json['caption'] as String?)?.trim().isNotEmpty == true
          ? (json['caption'] as String).trim()
          : null,
      editedAt: _parseEditedAt(json['editedAt']),
    );
  }

  static DateTime? _parseEditedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  ProfileCalendarEvent copyWith({
    bool? bookmarked,
    bool? inCalendar,
    String? calendarStatus,
    int? likesCount,
    int? commentsCount,
    ExploreAuthor? author,
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
      author: author ?? this.author,
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

  bool get canMarkNotGoing => !isPast && inCalendar && !isAuthoredByMe;
}

ProfileCalendarEvent overlayEditedProfileCalendarEvent(
  ProfileCalendarEvent event,
  Map<String, FeedPost> edits,
) {
  final edit = edits[event.postId];
  if (edit == null) return event;
  final details = edit.eventDetails;
  final loc = details.eventLocation;
  final dateRaw = details.date?.trim();
  var date = event.date;
  if (dateRaw != null && dateRaw.length >= 10) {
    date = DateTime.tryParse(dateRaw.substring(0, 10)) ?? event.date;
  }
  return ProfileCalendarEvent(
    postId: event.postId,
    date: date,
    location: edit.location,
    imageUrl: edit.imageUrl,
    status: edit.status ?? event.status,
    venue: (details.venue?.trim().isNotEmpty == true)
        ? details.venue!.trim()
        : (loc.name.isNotEmpty ? loc.name : event.venue),
    ticketUrl: details.ticketUrl ?? event.ticketUrl,
    time: details.time ?? event.time,
    country: event.country,
    place: loc.name.isNotEmpty ? loc.name : event.place,
    address: loc.formattedAddress.isNotEmpty
        ? loc.formattedAddress
        : event.address,
    calendarCount: event.calendarCount,
    viewCount: event.viewCount,
    likesCount: event.likesCount,
    commentsCount: event.commentsCount,
    author: event.author,
    bookmarked: event.bookmarked,
    source: event.source,
    isAuthoredByMe: event.isAuthoredByMe,
    inCalendar: event.inCalendar,
    calendarStatus: edit.calendarStatus ?? event.calendarStatus,
    hiddenOnProfile: event.hiddenOnProfile,
    caption: edit.caption.isNotEmpty ? edit.caption : event.caption,
    editedAt: edit.editedAt ?? DateTime.now(),
  );
}

Future<void> showProfileEventSheet({
  required BuildContext context,
  required ProfileCalendarEvent event,
  required String profileUsername,
  required bool isOwnProfile,
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
      isOwnProfile: isOwnProfile,
      onCalendarChanged: onCalendarChanged,
    ),
  );
}

class _ProfileEventSheet extends ConsumerStatefulWidget {
  const _ProfileEventSheet({
    required this.event,
    required this.profileUsername,
    required this.isOwnProfile,
    required this.onCalendarChanged,
  });

  final ProfileCalendarEvent event;
  final String profileUsername;
  final bool isOwnProfile;
  final VoidCallback onCalendarChanged;

  @override
  ConsumerState<_ProfileEventSheet> createState() => _ProfileEventSheetState();
}

class _ProfileEventSheetState extends ConsumerState<_ProfileEventSheet> {
  late ProfileCalendarEvent _event;
  ExploreAuthor? _author;
  bool _authorLoading = false;
  late bool _inCalendar;
  String? _calendarStatus;
  bool _busy = false;
  late int _likesCount;
  late int _commentsCount;
  late bool _hiddenOnProfile;

  /// One-shot attendees load for own events (no polling / no repeat calls).
  List<Map<String, dynamic>> _goingPeople = const [];
  int _goingCount = 0;
  bool _goingLoading = false;
  bool _goingLoaded = false;

  ProfileCalendarEvent get event => _event;

  ExploreAuthor? get _resolvedAuthor => _author ?? event.author;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _author = widget.event.author;
    _likesCount = event.likesCount;
    _commentsCount = event.commentsCount;
    _hiddenOnProfile = event.hiddenOnProfile;
    _syncCalendarFromViewer();
    _goingCount = event.calendarCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (event.isAuthoredByMe && event.postId.isNotEmpty) {
        _loadGoingOnce();
      }
      // Re-fetch viewer RSVP so we never show the profile owner's status.
      if (!event.isAuthoredByMe && event.postId.isNotEmpty) {
        _refreshViewerCalendarStatus();
      }
      if (!event.isAuthoredByMe) {
        unawaited(_loadAuthor());
      }
    });
  }

  Future<void> _loadAuthor() async {
    if (_authorLoading) return;
    final existing = _resolvedAuthor;
    if (existing != null && existing.username.trim().isNotEmpty) return;
    setState(() => _authorLoading = true);
    try {
      final resolved = await resolveEventSheetAuthor(
        ref: ref,
        postId: event.postId,
        existing: existing,
      );
      if (!mounted || resolved == null) return;
      setState(() {
        _author = resolved;
        _event = _event.copyWith(author: resolved);
      });
    } finally {
      if (mounted) setState(() => _authorLoading = false);
    }
  }

  void _syncCalendarFromViewer() {
    final resolved = resolveViewerCalendarStatus(
      store: ref.read(calendarStatusStoreProvider.notifier),
      postId: event.postId,
      apiCalendarStatus: event.calendarStatus,
      inCalendar: event.inCalendar,
      isMine: event.isAuthoredByMe,
      postStatus: event.status,
    );
    _calendarStatus = resolved;
    _inCalendar = event.isAuthoredByMe || resolved != null;
  }

  Future<void> _refreshViewerCalendarStatus() async {
    try {
      final post = await ref
          .read(postsRepositoryProvider)
          .fetchPost(event.postId);
      final status = post.calendarStatus;
      final inCal = post.inCalendar;
      final resolved = status ?? (inCal ? 'going' : null);
      ref
          .read(calendarStatusStoreProvider.notifier)
          .syncFromApi(event.postId, resolved);
      if (!mounted) return;
      setState(() {
        _calendarStatus = resolved;
        _inCalendar = resolved != null;
      });
    } catch (_) {
      // Keep store / API fallback already applied in initState.
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

  void _openGoingList() {
    if (event.postId.isEmpty || _goingCount < 1) return;
    showFeedAttendeesSheet(
      context: context,
      postId: event.postId,
      initialCount: _goingCount,
    );
  }

  Future<void> _setHiddenOnProfile(bool hide) async {
    if (_busy || event.postId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(postsRepositoryProvider);
      if (hide) {
        await repo.hideOnProfile(event.postId);
      } else {
        await repo.unhideOnProfile(event.postId);
      }
      if (!mounted) return;
      setState(() => _hiddenOnProfile = hide);
      if (event.isAuthoredByMe) {
        final hidden = ref.read(discoveryHiddenPostIdsProvider.notifier);
        if (hide) {
          hidden.markHidden(event.postId);
        } else {
          hidden.unhide(event.postId);
        }
      }
      // Toast before calendar refresh so the user still sees feedback.
      _toast(
        hide
            ? (event.isAuthoredByMe
                  ? 'Hidden from feed and your profile. Share the link to invite others.'
                  : 'Hidden from your profile')
            : (event.isAuthoredByMe
                  ? 'Visible in feed and on your profile again'
                  : 'Visible on your profile again'),
      );
      widget.onCalendarChanged();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    AppToast.show(context, message);
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

  /// Show creator when this event is not authored by the signed-in user.
  bool get _showCreatorRow {
    if (event.isAuthoredByMe) return false;
    final author = _resolvedAuthor;
    return author != null && author.username.trim().isNotEmpty;
  }

  void _openAttendees() {
    if (event.postId.isEmpty || event.calendarCount < 1) return;
    showFeedAttendeesSheet(
      context: context,
      postId: event.postId,
      initialCount: event.calendarCount,
    );
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
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
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
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
    bool purgedPost = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;

      // Capture navigator before pop/invalidate — sheet context dies after pop,
      // and calendar refresh can briefly drop the profile Scaffold.
      final navigator = Navigator.of(context);

      if (purgedPost && event.postId.isNotEmpty) {
        ref.read(deletedPostIdsProvider.notifier).markDeleted(event.postId);
        ref
            .read(calendarStatusStoreProvider.notifier)
            .setStatus(event.postId, null);
      }

      navigator.pop();

      if (purgedPost && event.postId.isNotEmpty) {
        ref.invalidate(exploreEventsProvider);
        ref.invalidate(sharedPostProvider(event.postId));
        ref.invalidate(profileMeProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
      }
      widget.onCalendarChanged();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppToast.show(navigator.context, success);
      });
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
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
      purgedPost: true,
    );
  }

  Future<void> _notGoing() async {
    if (event.postId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: event.postId, status: 'none');
      ref
          .read(calendarStatusStoreProvider.notifier)
          .setStatus(event.postId, null);
      if (!mounted) return;
      widget.onCalendarChanged();
      Navigator.of(context).pop();
      AppToast.show(context, 'Removed from your calendar');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openOwnerProfile() {
    final username = _resolvedAuthor?.username ?? '';
    if (username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(username));
  }

  Future<void> _openEdit() async {
    if (event.postId.isEmpty) return;
    await openEditPostScreen(context, event.postId, closeParent: true);
  }

  @override
  Widget build(BuildContext context) {
    final place = event.placeLabel;
    final fullLocation = event.fullLocationLabel;
    final timeLabel = event.formattedTime;
    final author = _resolvedAuthor;
    final showOwnInsights = event.isAuthoredByMe;
    final showGoingRow = showOwnInsights && _goingCount >= 1;
    final showVisitorAttendees = !showOwnInsights && event.calendarCount >= 1;
    final showViewsRow = showOwnInsights && event.viewCount > 0;
    final showOwnerStatusToggle =
        widget.isOwnProfile && event.isAuthoredByMe && !event.isPast;
    // Same Interested / Going RSVP as feed & explore (no wishlist).
    final showVisitorRsvp = !event.isAuthoredByMe && !event.isPast;
    final caption = event.caption?.trim() ?? '';
    final locationForShare = fullLocation.isNotEmpty
        ? fullLocation
        : (place.isEmpty ? null : place);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            // Keep sheet content taps from dismissing the modal.
            onTap: () {},
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
                              color: AppColors.mutedForeground.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _showCreatorRow && author != null
                                  ? EventSheetCreatorHeader(
                                      avatarUrl: author.avatarUrl,
                                      username: author.username,
                                      badge: author.badge,
                                      onTap: _openOwnerProfile,
                                    )
                                  : Text(
                                      'EVENT DETAILS',
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
                                    case 'edit':
                                      _openEdit();
                                    case 'hide':
                                      _setHiddenOnProfile(true);
                                    case 'unhide':
                                      _setHiddenOnProfile(false);
                                    case 'delete':
                                      _confirmDelete();
                                    case 'not_going':
                                      _notGoing();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: _hiddenOnProfile ? 'unhide' : 'hide',
                                    child: Text(
                                      _hiddenOnProfile
                                          ? 'Show on profile'
                                          : 'Hide event',
                                      style: AppTextStyles.body(
                                        14,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (event.isAuthoredByMe)
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(
                                        'Edit event',
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
                            else ...[
                              FeedPostMoreMenu(
                                postId: event.postId,
                                isPast: event.isPast,
                                isOwnPost: event.isAuthoredByMe,
                                authorUsername: author?.username ?? '',
                                authorId: author?.id ?? '',
                                closeParentOnEdit: true,
                              ),
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
                                  if (_hiddenOnProfile)
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
                          style: AppTextStyles.display(
                            24,
                            color: AppColors.secondary,
                          ),
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ExpandableCaption(
                            key: ValueKey('profile-caption-${event.postId}'),
                            text: caption,
                            trimLines: 3,
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
                                      trailing: event.isEdited
                                          ? const EventEditedBadge()
                                          : null,
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
                              if (showGoingRow && showViewsRow) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: _GoingInsightRow(
                                        count: _goingCount,
                                        people: _goingPeople,
                                        loading: _goingLoading,
                                        onOpenList: _openGoingList,
                                        compact: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: _MetaChip(
                                          icon: Icons.visibility_outlined,
                                          label: event.viewCount == 1
                                              ? '1 view'
                                              : '${event.viewCount} views',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (showGoingRow) ...[
                                const SizedBox(height: 10),
                                _GoingInsightRow(
                                  count: _goingCount,
                                  people: _goingPeople,
                                  loading: _goingLoading,
                                  onOpenList: _openGoingList,
                                ),
                              ] else if (showViewsRow) ...[
                                const SizedBox(height: 10),
                                _MetaChip(
                                  icon: Icons.visibility_outlined,
                                  label: event.viewCount == 1
                                      ? '1 view'
                                      : '${event.viewCount} views',
                                  expanded: true,
                                  maxLines: 1,
                                ),
                              ],
                              if (showVisitorAttendees) ...[
                                const SizedBox(height: 10),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openAttendees,
                                    child: _MetaChip(
                                      icon: Icons.person_outline,
                                      label: event.calendarCount == 1
                                          ? '1 Person'
                                          : '${event.calendarCount} People',
                                    ),
                                  ),
                                ),
                              ],
                              if (showOwnerStatusToggle) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: calendarButtonBackground(
                                        _calendarStatus,
                                      ),
                                      foregroundColor: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
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
                                            calendarButtonLabel(
                                              _calendarStatus,
                                            ),
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
                              ] else if (showVisitorRsvp) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: calendarButtonBackground(
                                        _calendarStatus,
                                      ),
                                      foregroundColor: calendarButtonForeground(
                                        _calendarStatus,
                                      ),
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
                                            calendarButtonLabel(
                                              _calendarStatus,
                                            ),
                                            style: AppTextStyles.display(
                                              14,
                                              color: calendarButtonForeground(
                                                _calendarStatus,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (_inCalendar) ...[
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
                              onTap: event.postId.isEmpty
                                  ? null
                                  : _openComments,
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
                                        AppToast.show(
                                          context,
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
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
    this.maxLines = 3,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final int maxLines;
  final Widget? trailing;

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
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
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
    this.compact = false,
  });

  final int count;
  final List<Map<String, dynamic>> people;
  final bool loading;
  final VoidCallback onOpenList;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 Person' : '$count People';

    final row = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        const Icon(
          Icons.people_outline,
          size: 16,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              13.5,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ),
        if (!compact) ...[
          const Spacer(),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.mutedForeground,
          ),
        ] else
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.mutedForeground,
          ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenList,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      ),
    );
  }
}

// class _GoingFace extends StatelessWidget {
//   const _GoingFace({required this.user});

//   final Map<String, dynamic> user;

//   @override
//   Widget build(BuildContext context) {
//     final username = (user['username'] as String?)?.trim() ?? '';
//     final avatarUrl = (user['avatarUrl'] as String?)?.trim() ?? '';
//     return AuthorAvatar(
//       avatarUrl: avatarUrl,
//       username: username,
//       size: 36,
//       interactive: false,
//     );
//   }
// }
