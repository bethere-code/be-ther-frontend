import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/background_tasks/event_view_recorder.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/design/widgets/event_edited_badge.dart';
import '../../../../core/design/widgets/event_sheet_creator_row.dart';
import '../../../../core/design/widgets/expandable_caption.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../feed/presentation/calendar_status_store.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../feed/presentation/widgets/calendar_rsvp_sheet.dart';
import '../../../feed/presentation/widgets/feed_attendees_sheet.dart';
import '../../../feed/presentation/widgets/feed_comments_sheet.dart';
import '../../../feed/presentation/widgets/feed_likes_sheet.dart';
import '../../../feed/presentation/widgets/feed_post_more_menu.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../../domain/explore_event.dart';
import 'package:be_ther/core/ui/app_toast.dart';

String exploreEventHeroTag(String postId) => 'explore-event-image-$postId';

Future<void> showExploreEventSheet({
  required BuildContext context,
  required ExploreEvent event,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.secondary.withValues(alpha: 0.45),
    builder: (context) => _ExploreEventSheet(event: event),
  );
}

class _ExploreEventSheet extends ConsumerStatefulWidget {
  const _ExploreEventSheet({required this.event});

  final ExploreEvent event;

  @override
  ConsumerState<_ExploreEventSheet> createState() => _ExploreEventSheetState();
}

class _ExploreEventSheetState extends ConsumerState<_ExploreEventSheet> {
  late ExploreEvent _event;
  ExploreAuthor? _author;
  bool _authorLoading = false;
  late bool _inCalendar;
  String? _calendarStatus;
  bool _calendarBusy = false;
  late int _likesCount;
  late int _commentsCount;

  ExploreEvent get event => _event;

  ExploreAuthor? get _resolvedAuthor => _author ?? event.author;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _author = widget.event.author;
    _likesCount = event.likesCount;
    _commentsCount = event.commentsCount;
    _syncCalendarStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || event.postId.isEmpty) return;
      _syncCalendarStatus(notify: true);
      unawaited(_loadAuthor());
      final me = ref.read(authNotifierProvider).user;
      if (!_isOwnEvent(me)) {
        ref.read(eventViewRecorderProvider).enqueue(event.postId);
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

  void _syncCalendarStatus({bool notify = false}) {
    final me = ref.read(authNotifierProvider).user;
    final isMine = _isOwnEvent(me);
    final resolved = resolveViewerCalendarStatus(
      store: ref.read(calendarStatusStoreProvider.notifier),
      postId: event.postId,
      apiCalendarStatus: event.calendarStatus,
      inCalendar: event.inCalendar,
      isMine: isMine,
      postStatus: event.status,
    );
    final nextIn = isMine || resolved != null;
    if (!notify) {
      _calendarStatus = resolved;
      _inCalendar = nextIn;
      return;
    }
    if (resolved != _calendarStatus || nextIn != _inCalendar) {
      setState(() {
        _calendarStatus = resolved;
        _inCalendar = nextIn;
      });
    }
  }

  bool _isOwnEvent(Map<String, dynamic>? me) {
    final myId = me?['_id']?.toString() ?? me?['id']?.toString() ?? '';
    return isOwnEventByAuthorIds(
      myUserId: myId,
      eventAuthorUserId: event.authorUserId,
      resolvedAuthor: _resolvedAuthor,
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

  void _openAttendees() {
    if (event.postId.isEmpty || event.attendees < 1) return;
    showFeedAttendeesSheet(
      context: context,
      postId: event.postId,
      initialCount: event.attendees,
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

  Future<void> _handleCalendarTap() async {
    if (event.postId.isEmpty || _calendarBusy || event.isPast) return;
    final me = ref.read(authNotifierProvider).user;
    final isMine = _isOwnEvent(me);
    final current = resolveViewerCalendarStatus(
      store: ref.read(calendarStatusStoreProvider.notifier),
      postId: event.postId,
      apiCalendarStatus: event.calendarStatus ?? _calendarStatus,
      inCalendar: event.inCalendar || _inCalendar,
      isMine: isMine,
      postStatus: event.status,
    );
    final choice = await showCalendarRsvpSheet(
      context: context,
      alreadyOnCalendar: isMine ? true : current != null,
      currentStatus: current ?? (isMine ? 'going' : null),
      allowRemove: !isMine,
    );
    if (choice == null || !mounted) return;
    if (isMine && choice == CalendarRsvpChoice.none) return;

    final status = switch (choice) {
      CalendarRsvpChoice.interested => 'interested',
      CalendarRsvpChoice.going => 'going',
      CalendarRsvpChoice.none => 'none',
    };

    setState(() => _calendarBusy = true);
    try {
      final data = await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: event.postId, status: status);
      final cleared = status == 'none';
      final nextStatus = cleared ? null : data['calendarStatus'] as String?;
      final inCalendar = cleared
          ? false
          : (data['inCalendar'] as bool? ?? (nextStatus != null));
      final resolved = inCalendar
          ? (nextStatus ?? status)
          : (isMine ? status : null);
      ref
          .read(calendarStatusStoreProvider.notifier)
          .setStatus(event.postId, isMine ? (nextStatus ?? status) : resolved);
      final meUsername =
          ref.read(authNotifierProvider).user?['username'] as String?;
      if (meUsername != null && meUsername.isNotEmpty) {
        ref.invalidate(profileCalendarProvider(meUsername));
      }
      if (mounted) {
        setState(() {
          if (isMine) {
            _calendarStatus = nextStatus ?? status;
            _inCalendar = true;
          } else {
            _calendarStatus = resolved;
            _inCalendar = resolved != null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  void _openCreatorProfile() {
    final username = event.author?.username ?? '';
    if (username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(username));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authNotifierProvider).user;
    final isOwnEvent = _isOwnEvent(me);
    // Keep button in sync if feed/explore updated RSVP while this sheet is open.
    ref.watch(calendarStatusStoreProvider);
    final effectiveStatus = resolveViewerCalendarStatus(
      store: ref.read(calendarStatusStoreProvider.notifier),
      postId: event.postId,
      apiCalendarStatus: event.calendarStatus ?? _calendarStatus,
      inCalendar: event.inCalendar || _inCalendar,
      isMine: isOwnEvent,
      postStatus: event.status,
    );
    final author = _resolvedAuthor;
    final place = event.placeLabel;
    final dateLabel = event.formattedDateOnly;
    final timeLabel = event.formattedTime;
    final showCreator =
        !isOwnEvent && author != null && author.username.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          // Keep sheet content taps from dismissing.
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
                        child: showCreator
                            ? EventSheetCreatorHeader(
                                avatarUrl: author.avatarUrl,
                                username: author.username,
                                badge: author.badge,
                                onTap: _openCreatorProfile,
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
                      FeedPostMoreMenu(
                        postId: event.postId,
                        isPast: event.isPast,
                        isOwnPost: isOwnEvent,
                        authorUsername: author?.username ?? '',
                        authorId: author?.id ?? event.authorUserId,
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
                  ),
                  if (event.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Hero(
                        tag: event.heroTag,
                        child: Material(
                          color: AppColors.card,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              BeTherNetworkImage(
                                url: event.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (event.trending) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: AppColors.accent,
                        child: Text(
                          'HOT',
                          style: AppTextStyles.display(
                            10,
                            color: AppColors.accentForeground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    event.title,
                    style: AppTextStyles.display(
                      24,
                      color: AppColors.secondary,
                    ),
                  ),
                  if ((event.caption ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ExpandableCaption(
                      key: ValueKey('explore-caption-${event.id}'),
                      text: event.caption!.trim(),
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
                            if (dateLabel != null)
                              _MetaChip(
                                icon: Icons.calendar_today_outlined,
                                label: dateLabel,
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
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _MetaChip(
                            icon: Icons.place_outlined,
                            label: place,
                            expanded: true,
                          ),
                        ],
                        if (event.showAttendees) ...[
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openAttendees,
                              child: _MetaChip(
                                icon: Icons.person_outline,
                                label: event.attendees == 1
                                    ? '1 Person'
                                    : '${event.attendees} People',
                              ),
                            ),
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
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: calendarButtonBackground(
                                  effectiveStatus,
                                ),
                                foregroundColor: calendarButtonForeground(
                                  effectiveStatus,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: _calendarBusy
                                  ? null
                                  : _handleCalendarTap,
                              child: _calendarBusy
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: calendarButtonForeground(
                                          effectiveStatus,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      calendarButtonLabel(effectiveStatus),
                                      style: AppTextStyles.display(
                                        14,
                                        color: calendarButtonForeground(
                                          effectiveStatus,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (event.hasTicketUrl)
                        IconButton(
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
                        onPressed: event.postId.isEmpty
                            ? null
                            : () async {
                                try {
                                  await sharePostContent(
                                    postId: event.postId,
                                    location: event.title.isNotEmpty
                                        ? event.title
                                        : place,
                                    imageUrl: event.imageUrl,
                                    ticketUrl: event.ticketUrl,
                                    caption: event.caption,
                                    venue: place.isEmpty ? null : place,
                                    date: dateLabel,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  AppToast.show(
                                    context,
                                    e.toString().replaceFirst('Exception: ', ''),
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
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.expanded = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final Widget? trailing;

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
            maxLines: expanded ? 3 : 1,
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
