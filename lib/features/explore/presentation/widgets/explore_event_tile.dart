import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../feed/presentation/calendar_status_store.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../feed/presentation/widgets/calendar_rsvp_sheet.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../domain/explore_event.dart';
import 'explore_event_sheet.dart';

/// Shared layout constants for explore / search event tiles.
abstract final class ExploreEventTileLayout {
  static const double calendarHeight = 36;
  static const double ticketButtonSize = 25;
  static const int crossAxisCount = 2;
  static const double gridSpacing = 14;
  static const double imageMaxHeight = 220;

  /// Slightly taller than square so default covers + event posters fill masonry.
  static double imageHeight(double tileWidth) {
    final target = tileWidth * 1.2;
    return target > imageMaxHeight ? imageMaxHeight : target;
  }
}

/// Event card used on Explore and Search masonry grids.
/// Heights shrink-wrap to content (no fixed aspect ratio).
class ExploreEventTile extends ConsumerStatefulWidget {
  const ExploreEventTile({super.key, required this.event});

  final ExploreEvent event;

  @override
  ConsumerState<ExploreEventTile> createState() => _ExploreEventTileState();
}

class _ExploreEventTileState extends ConsumerState<ExploreEventTile> {
  late bool _inCalendar;
  String? _calendarStatus;
  bool _calendarBusy = false;

  @override
  void initState() {
    super.initState();
    _syncFromEvent();
  }

  @override
  void didUpdateWidget(covariant ExploreEventTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.inCalendar != widget.event.inCalendar ||
        oldWidget.event.calendarStatus != widget.event.calendarStatus ||
        oldWidget.event.postId != widget.event.postId) {
      _syncFromEvent();
    }
  }

  void _syncFromEvent() {
    final postId = widget.event.postId;
    final api =
        widget.event.calendarStatus ??
        (widget.event.inCalendar ? 'going' : null);
    _calendarStatus = ref
        .read(calendarStatusStoreProvider.notifier)
        .statusFor(postId, fallback: api);
    _inCalendar = _calendarStatus != null;
  }

  bool _isMine(Map<String, dynamic>? me) {
    final author = widget.event.author;
    if (me == null || author == null) return false;
    final myId = me['_id']?.toString() ?? me['id']?.toString() ?? '';
    if (myId.isNotEmpty && author.id.isNotEmpty && myId == author.id) {
      return true;
    }
    final myUsername = (me['username'] as String?)?.trim() ?? '';
    final authorUsername = author.username.trim();
    return myUsername.isNotEmpty &&
        authorUsername.isNotEmpty &&
        myUsername.toLowerCase() == authorUsername.toLowerCase();
  }

  Future<void> _handleCalendarTap() async {
    final postId = widget.event.postId;
    if (postId.isEmpty || _calendarBusy || widget.event.isPast) return;

    final me = ref.read(authNotifierProvider).user;
    final isMine = _isMine(me);
    final choice = await showCalendarRsvpSheet(
      context: context,
      alreadyOnCalendar: isMine ? true : _inCalendar,
      currentStatus: _calendarStatus ?? (isMine ? 'going' : null),
      // Authors cannot remove their own event from calendar.
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
          .setCalendarStatus(postId: postId, status: status);
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
          .setStatus(postId, isMine ? (nextStatus ?? status) : resolved);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  void _openSheet() {
    if (widget.event.postId.isEmpty) return;
    showExploreEventSheet(context: context, event: widget.event);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final store = ref.watch(calendarStatusStoreProvider);
    final id = event.postId;
    final apiFallback =
        event.calendarStatus ?? (event.inCalendar ? 'going' : null);
    final effectiveStatus = store.containsKey(id)
        ? store[id]
        : (_calendarStatus ?? apiFallback);
    final placeShort = event.placeShort;
    final dateLabel = event.formattedDateOnly;
    final timeLabel = event.formattedTime;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = ExploreEventTileLayout.imageHeight(
          constraints.maxWidth,
        );
        return Material(
          color: AppColors.card,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
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
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: InkWell(
                    onTap: _openSheet,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Hero(
                            tag: event.heroTag,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Material(
                                type: MaterialType.transparency,
                                child: BeTherNetworkImage(
                                  url: event.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (event.trending)
                          const Positioned(top: 8, left: 8, child: _HotBadge()),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _openSheet,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.title.trim().isNotEmpty)
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.display(
                              16,
                              color: AppColors.secondary,
                              letterSpacing: 0.08,
                            ),
                          ),
                        if (placeShort.isNotEmpty) ...[
                          if (event.title.trim().isNotEmpty)
                            const SizedBox(height: 6),
                          _MetaRow(
                            icon: Icons.place_outlined,
                            label: placeShort,
                          ),
                        ],
                        if (dateLabel != null ||
                            (timeLabel != null && timeLabel.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          _DateTimeRow(date: dateLabel, time: timeLabel),
                        ],
                        const SizedBox(height: 8),
                        if (event.showAttendees || event.hasTicketUrl) ...[
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.border,
                                  width: AppDimens.borderThinnest,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  if (event.showAttendees) ...[
                                    const Icon(
                                      Icons.person_outline,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${event.attendees}',
                                      style: AppTextStyles.body(
                                        14,
                                        weight: FontWeight.w700,
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (event.hasTicketUrl)
                                    _TicketCircleButton(
                                      onTap: () => openExternalUrl(
                                        context,
                                        event.ticketUrl!,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: _ExploreCalendarButton(
                    calendarStatus: effectiveStatus,
                    isPast: event.isPast,
                    loading: _calendarBusy,
                    onPressed: event.postId.isEmpty || event.isPast
                        ? null
                        : _handleCalendarTap,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HotBadge extends StatelessWidget {
  const _HotBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        border: Border.all(
          color: AppColors.background,
          width: AppDimens.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: AppColors.accentForeground),
          const SizedBox(width: 4),
          Text(
            'HOT',
            style: AppTextStyles.display(
              10,
              color: AppColors.accentForeground,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCircleButton extends StatelessWidget {
  const _TicketCircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: ExploreEventTileLayout.ticketButtonSize,
          height: ExploreEventTileLayout.ticketButtonSize,
          child: Center(
            child: Icon(
              Icons.open_in_new,
              size: 14,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({this.date, this.time});

  final String? date;
  final String? time;

  static final TextStyle _metaStyle = AppTextStyles.body(
    11,
    color: AppColors.mutedForeground,
    weight: FontWeight.w600,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null && date!.isNotEmpty;
    final hasTime = time != null && time!.isNotEmpty;
    if (!hasDate && !hasTime) return const SizedBox.shrink();

    // Stack time under date so narrow grid tiles don't truncate the year.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDate)
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  date!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle,
                ),
              ),
            ],
          ),
        if (hasDate && hasTime) const SizedBox(height: 8),
        if (hasTime)
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 12,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  time!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              12,
              color: AppColors.mutedForeground,
              weight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreCalendarButton extends StatelessWidget {
  const _ExploreCalendarButton({
    required this.calendarStatus,
    required this.isPast,
    required this.loading,
    required this.onPressed,
  });

  final String? calendarStatus;
  final bool isPast;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = isPast
        ? AppColors.muted
        : calendarButtonBackground(calendarStatus);
    final fg = isPast
        ? AppColors.mutedForeground
        : calendarButtonForeground(calendarStatus);
    final label = isPast ? 'PAST EVENT' : calendarTileLabel(calendarStatus);

    return SizedBox(
      height: ExploreEventTileLayout.calendarHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : Text(
                        label,
                        key: ValueKey(label),
                        style: AppTextStyles.display(
                          11,
                          color: fg,
                          letterSpacing: 0.05,
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
