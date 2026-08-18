import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/background_tasks/event_view_recorder.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/design/widgets/expandable_caption.dart';
import '../../../../core/design/widgets/post_interaction_row.dart';
import '../../../../core/design/widgets/pressable.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/post_author.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../calendar_status_store.dart';
import '../feed_providers.dart';
import 'calendar_rsvp_sheet.dart';
import 'feed_attendees_sheet.dart';
import 'feed_post_more_menu.dart';

/// Full feed-style event card (author, media, details, RSVP, interactions).
class FeedPostCard extends ConsumerStatefulWidget {
  const FeedPostCard({
    super.key,
    required this.item,
    this.recordFeedImpression = true,
    this.onInteractionChanged,
  });

  final Map<String, dynamic> item;
  final bool recordFeedImpression;
  final VoidCallback? onInteractionChanged;

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard> {
  late bool _inCalendar;
  String? _calendarStatus;
  late int _attendeesCount;
  bool _isCalendarLoading = false;
  String? _calendarError;
  bool _feedViewScheduled = false;

  @override
  void initState() {
    super.initState();
    _syncFromItem();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleFeedImpression();
    });
  }

  @override
  void didUpdateWidget(covariant FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['inCalendar'] != widget.item['inCalendar'] ||
        oldWidget.item['calendarCount'] != widget.item['calendarCount'] ||
        oldWidget.item['calendarStatus'] != widget.item['calendarStatus']) {
      _syncFromItem();
    }
    final oldId = oldWidget.item['_id']?.toString() ?? '';
    final newId = widget.item['_id']?.toString() ?? '';
    if (oldId != newId) {
      _feedViewScheduled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleFeedImpression();
      });
    }
  }

  void _syncFromItem() {
    final postId = widget.item['_id']?.toString() ?? '';
    final apiStatus = widget.item['calendarStatus'] as String?;
    final postStatus = widget.item['status'] as String?;
    final fromStore = resolveViewerCalendarStatus(
      store: ref.read(calendarStatusStoreProvider.notifier),
      postId: postId,
      apiCalendarStatus: apiStatus,
      inCalendar: widget.item['inCalendar'] as bool? ?? false,
      isMine: _isOwnPost,
      postStatus: postStatus,
    );
    _calendarStatus = fromStore;
    _inCalendar = _isOwnPost || _calendarStatus != null;
    _attendeesCount = (widget.item['calendarCount'] as num?)?.toInt() ?? 0;
  }

  /// Feed counts an impression without opening a details sheet.
  /// Explore/search only count on sheet open; [EventViewRecorder] dedupes both.
  void _scheduleFeedImpression() {
    if (!widget.recordFeedImpression) return;
    if (_feedViewScheduled || _isOwnPost) return;
    final postId = widget.item['_id']?.toString() ?? '';
    if (postId.isEmpty) return;
    _feedViewScheduled = true;

    // Slight delay so feed pagination / scroll requests stay ahead of views.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(eventViewRecorderProvider).enqueue(postId);
    });
  }

  bool get _isOwnPost {
    final me = ref.read(authNotifierProvider).user;
    if (me == null) return false;
    final myId = me['_id']?.toString() ?? me['id']?.toString() ?? '';
    final myUsername = (me['username'] as String?)?.trim() ?? '';
    final author = readPostAuthor(widget.item);
    final authorId =
        author['_id']?.toString() ?? author['id']?.toString() ?? '';
    final authorUsername = (author['username'] as String?)?.trim() ?? '';
    if (myId.isNotEmpty && authorId.isNotEmpty && myId == authorId) {
      return true;
    }
    if (myUsername.isNotEmpty &&
        authorUsername.isNotEmpty &&
        myUsername == authorUsername) {
      return true;
    }
    return false;
  }

  Future<void> _handleCalendarTap(String postId) async {
    if (postId.isEmpty || _isCalendarLoading) return;

    final choice = await showCalendarRsvpSheet(
      context: context,
      alreadyOnCalendar: _isOwnPost ? true : _inCalendar,
      currentStatus: _calendarStatus,
      allowRemove: !_isOwnPost,
    );
    if (choice == null || !mounted) return;
    if (_isOwnPost && choice == CalendarRsvpChoice.none) return;

    final status = switch (choice) {
      CalendarRsvpChoice.interested => 'interested',
      CalendarRsvpChoice.going => 'going',
      CalendarRsvpChoice.none => 'none',
    };

    final wasIn = _inCalendar;
    setState(() {
      _isCalendarLoading = true;
      _calendarError = null;
    });

    try {
      final data = await ref
          .read(postsRepositoryProvider)
          .setCalendarStatus(postId: postId, status: status);
      final cleared = status == 'none';
      final nextStatus = cleared ? null : data['calendarStatus'] as String?;
      final inCalendar = cleared
          ? false
          : (data['inCalendar'] as bool? ?? (nextStatus != null));
      final resolved = inCalendar
          ? (nextStatus ?? (status == 'none' ? null : status))
          : null;

      ref
          .read(calendarStatusStoreProvider.notifier)
          .setStatus(postId, resolved);

      final meUsername =
          ref.read(authNotifierProvider).user?['username'] as String?;
      if (meUsername != null && meUsername.isNotEmpty) {
        ref.invalidate(profileCalendarProvider(meUsername));
      }

      if (mounted) {
        setState(() {
          _calendarStatus = resolved ?? (_isOwnPost ? status : null);
          _inCalendar = _isOwnPost ? true : resolved != null;
          if (!_isOwnPost) {
            if (wasIn && !inCalendar) {
              _attendeesCount = (_attendeesCount - 1).clamp(0, 1 << 30);
            } else if (!wasIn && inCalendar) {
              _attendeesCount += 1;
            }
          }
        });
        widget.onInteractionChanged?.call();
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

  void _openAttendees(String postId) {
    if (postId.isEmpty) return;
    showFeedAttendeesSheet(
      context: context,
      postId: postId,
      initialCount: _attendeesCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final id = item['_id']?.toString() ?? '';
    final store = ref.watch(calendarStatusStoreProvider);
    final apiFallback =
        (item['calendarStatus'] as String?) ??
        (_isOwnPost
            ? ((item['status'] as String?) == 'interested'
                  ? 'interested'
                  : 'going')
            : ((item['inCalendar'] as bool? ?? false) ? 'going' : null));
    final effectiveStatus = store.containsKey(id)
        ? store[id]
        : (_calendarStatus ?? apiFallback);
    final effectiveInCalendar = _isOwnPost ? true : effectiveStatus != null;

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
    final imageUrl = item['imageUrl'] as String? ?? '';
    final caption = item['caption'] as String? ?? '';
    final likes = item['likesCount'] as int? ?? 0;
    final comments = item['commentsCount'] as int? ?? 0;
    final details = item['eventDetails'] as Map<String, dynamic>?;
    final ticketUrl = details?['ticketUrl'] as String?;
    final isPast = EventDateUtils.isPostPast(item);
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
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                AuthorAvatar(
                  avatarUrl: avatar,
                  username: username,
                  badge: badge,
                  size: 44,
                  heroTag: id.isEmpty ? null : 'avatar-$id',
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
                FeedPostMoreMenu(
                  postId: id,
                  isPast: isPast,
                  isOwnPost: _isOwnPost,
                ),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 12,
                //     vertical: 6,
                //   ),
                //   decoration: BoxDecoration(
                //     color: status == 'been'
                //         ? AppColors.primary
                //         : status == 'going'
                //         ? AppColors.accent
                //         : AppColors.muted,
                //     border: Border.all(
                //       color: AppColors.border,
                //       width: AppDimens.border,
                //     ),
                //   ),
                //   child: Text(
                //     status == 'been'
                //         ? 'BEEN'
                //         : status == 'going'
                //         ? 'GOING'
                //         : 'INTERESTED',
                //     style: AppTextStyles.display(
                //       14,
                //       color: status == 'been'
                //           ? AppColors.primaryForeground
                //           : status == 'going'
                //           ? AppColors.accentForeground
                //           : AppColors.foreground,
                //       letterSpacing: 0.05,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          if (id.isNotEmpty)
            Hero(
              tag: 'post-image-$id',
              child: AspectRatio(
                aspectRatio: 21 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BeTherNetworkImage(url: imageUrl, fit: BoxFit.cover),
                // Positioned(
                //   top: 12,
                //   right: 12,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 10,
                //       vertical: 8,
                //     ),
                //     color: AppColors.secondary.withValues(alpha: 0.9),
                //     child: Row(
                //       children: [
                //         const Icon(
                //           Icons.place,
                //           color: AppColors.background,
                //           size: 16,
                //         ),
                //         const SizedBox(width: 6),
                //         Text(
                //           country,
                //           style: AppTextStyles.display(
                //             12,
                //             color: AppColors.background,
                //             letterSpacing: 0.05,
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          )
          else
            AspectRatio(
              aspectRatio: 21 / 9,
              child: BeTherNetworkImage(url: imageUrl, fit: BoxFit.cover),
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
          caption.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: ExpandableCaption(
                    key: ValueKey('caption-$id'),
                    text: caption,
                    trimLines: 3,
                  ),
                )
              : const SizedBox.shrink(),
          if (details != null && details.isNotEmpty)
            _EventDetails(
              details,
              isPast: isPast,
              calendarStatus: effectiveStatus,
              inCalendar: effectiveInCalendar,
              isOwnPost: _isOwnPost,
              attendeesCount: _attendeesCount,
              isLoading: _isCalendarLoading,
              error: _calendarError,
              onCalendarToggle: () => _handleCalendarTap(id),
              onAttendeesTap: () => _openAttendees(id),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.mutedForeground,
                  width: AppDimens.borderThinnest,
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
              imageUrl: imageUrl,
              onInteractionChanged: widget.onInteractionChanged,
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
    this.isPast = false,
    this.calendarStatus,
    this.inCalendar = false,
    this.isOwnPost = false,
    this.attendeesCount = 0,
    this.isLoading = false,
    this.error,
    this.onCalendarToggle,
    this.onAttendeesTap,
  });

  final Map<String, dynamic> details;
  final bool isPast;
  final String? calendarStatus;
  final bool inCalendar;
  final bool isOwnPost;
  final int attendeesCount;
  final bool isLoading;
  final String? error;
  final VoidCallback? onCalendarToggle;
  final VoidCallback? onAttendeesTap;

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

  /// Accepts `HH:mm` / `H:mm` (and already-localized strings) → `h:mm AM/PM`.
  static String? _formatDisplayTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    final twelve = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(trimmed);
    if (twelve != null) {
      var hour = int.parse(twelve.group(1)!);
      final minute = twelve.group(2)!;
      final period = twelve.group(3)!.toUpperCase();
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (twentyFour != null) {
      var hour = int.parse(twentyFour.group(1)!);
      final minute = twentyFour.group(2)!;
      if (hour < 0 || hour > 23) return trimmed;
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final dateRaw = details['date'] as String?;
    final time = details['time'] as String?;
    final venue = details['venue'] as String?;
    final eventLocation = details['eventLocation'] is Map<String, dynamic>
        ? details['eventLocation'] as Map<String, dynamic>
        : null;
    final formattedAddress =
        (eventLocation?['formattedAddress'] as String?)?.trim();
    final displayDate = _formatDisplayDate(dateRaw);
    final displayTime = _formatDisplayTime(time);
    final displayVenue = (formattedAddress != null && formattedAddress.isNotEmpty)
        ? formattedAddress
        : venue?.trim();
    final hasDateTime =
        displayDate != null || (displayTime != null && displayTime.isNotEmpty);
    final hasVenue = displayVenue != null && displayVenue.isNotEmpty;
    final showAttendees = attendeesCount > 0;
    final hasMeta = hasDateTime || hasVenue || showAttendees;
    final showCalendarButton = !isPast;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(
            color: AppColors.mutedForeground,
            width: AppDimens.borderThinnest,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDateTime)
            Wrap(
              spacing: 20,
              runSpacing: 8,
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
              ],
            ),
          if (hasVenue) ...[
            if (hasDateTime) const SizedBox(height: 10),
            _EventDetailMeta(
              icon: Icons.place_outlined,
              label: displayVenue,
              expanded: true,
              maxLines: 3,
            ),
          ],
          if (showAttendees) ...[
            if (hasDateTime || hasVenue) const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAttendeesTap,
                child: _EventDetailMeta(
                  icon: Icons.people_outline,
                  label: attendeesCount == 1
                      ? '1 Person'
                      : '$attendeesCount People',
                  expanded: true,
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ),
          ],
          if (isPast) ...[
            if (hasMeta) const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.muted,
              child: Text(
                'PAST EVENT',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ] else ...[
            if (showCalendarButton) ...[
              if (hasMeta) const SizedBox(height: 12),
              Pressable(
                onTap: onCalendarToggle,
                enabled: !isLoading,
                haptic: true,
                scale: 0.97,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: calendarButtonBackground(calendarStatus),
                      foregroundColor: calendarButtonForeground(calendarStatus),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: isLoading ? null : onCalendarToggle,
                    child: Text(
                      calendarButtonLabel(calendarStatus),
                      style: AppTextStyles.display(
                        14,
                        color: calendarButtonForeground(calendarStatus),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
  const _EventDetailMeta({
    required this.icon,
    required this.label,
    this.expanded = false,
    this.maxLines = 1,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final int maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lines = maxLines.clamp(1, 3);
    final labelText = Text(
      label,
      style: AppTextStyles.body(
        13,
        color: AppColors.secondary,
        weight: FontWeight.w700,
      ),
      maxLines: lines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );

    if (!expanded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.secondary),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: labelText,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: AppColors.secondary),
        ),
        const SizedBox(width: 6),
        Expanded(child: labelText),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    );
  }
}

