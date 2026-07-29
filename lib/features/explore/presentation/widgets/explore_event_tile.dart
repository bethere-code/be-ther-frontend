import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../domain/explore_event.dart';
import 'explore_event_sheet.dart';

/// Shared layout constants for explore / search event tiles.
abstract final class ExploreEventTileLayout {
  static const double calendarHeight = 36;
  static const double ticketButtonSize = 30;
  static const int crossAxisCount = 2;
  static const double gridSpacing = 14;
  static const double imageMaxHeight = 160;

  /// Width-driven image height, capped so masonry tiles stay compact.
  static double imageHeight(double tileWidth) =>
      tileWidth > imageMaxHeight ? imageMaxHeight : tileWidth;
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
  bool _calendarBusy = false;

  @override
  void initState() {
    super.initState();
    _inCalendar = widget.event.inCalendar;
  }

  @override
  void didUpdateWidget(covariant ExploreEventTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.inCalendar != widget.event.inCalendar) {
      _inCalendar = widget.event.inCalendar;
    }
  }

  Future<void> _toggleCalendar() async {
    final postId = widget.event.postId;
    if (postId.isEmpty || _calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final next = await ref
          .read(postsRepositoryProvider)
          .toggleCalendar(postId);
      if (mounted) setState(() => _inCalendar = next);
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
    final placeShort = event.placeShort;
    final dateLabel = event.formattedDateOnly;
    final timeLabel = event.time?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        // final imageHeight = ExploreEventTileLayout.imageHeight(
        //   constraints.maxWidth,
        // );
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
                  height: 124.275,
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
                                  fit: BoxFit.contain,
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
                              letterSpacing: 0.02,
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
                          const SizedBox(height: 6),
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
                    inCalendar: _inCalendar,
                    isPast: event.isPast,
                    loading: _calendarBusy,
                    onPressed: event.postId.isEmpty || event.isPast
                        ? null
                        : _toggleCalendar,
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

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null && date!.isNotEmpty;
    final hasTime = time != null && time!.isNotEmpty;
    if (!hasDate && !hasTime) return const SizedBox.shrink();

    return Row(
      children: [
        if (hasDate) ...[
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              date!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                11,
                color: AppColors.mutedForeground,
                weight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
        if (hasDate && hasTime) const SizedBox(width: 8),
        if (hasTime) ...[
          const Icon(
            Icons.access_time,
            size: 12,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 4),
          Text(
            time!,
            maxLines: 1,
            style: AppTextStyles.body(
              11,
              color: AppColors.mutedForeground,
              weight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
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
    required this.inCalendar,
    required this.isPast,
    required this.loading,
    required this.onPressed,
  });

  final bool inCalendar;
  final bool isPast;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = isPast
        ? AppColors.muted
        : (inCalendar ? AppColors.primary : AppColors.accent);
    final fg = isPast
        ? AppColors.mutedForeground
        : (inCalendar
              ? AppColors.primaryForeground
              : AppColors.accentForeground);
    final label = isPast
        ? 'PAST EVENT'
        : (inCalendar ? 'ADDED' : 'ADD TO CALENDAR');

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
