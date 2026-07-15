import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/shell_header_avatar.dart';
import '../../../core/utils/link_utils.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/explore_event.dart';
import 'explore_providers.dart';
import 'widgets/explore_event_sheet.dart';

abstract final class _ExploreTileLayout {
  static const double calendarHeight = 36;
  static const double ticketButtonSize = 28;
  static double imageHeight(double tileWidth) => tileWidth;
}

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(exploreEventsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(FeedScreen.path);
      },
      child: AppShell(
        activeTab: ShellTab.explore,
        header: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              children: [
                const ShellHeaderAvatar(),
                Expanded(
                  child: Center(
                    child: Text(
                      'EXPLORE',
                      style: AppTextStyles.display(
                        28,
                        color: AppColors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(SearchScreen.path),
                  icon: const Icon(
                    Icons.search,
                    color: AppColors.background,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopUpcomingHeader(),
              Expanded(
                child: events.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No posts to explore yet',
                          style: AppTextStyles.body(
                            16,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.card,
                      onRefresh: () =>
                          ref.refresh(exploreEventsProvider.future),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.53,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _ExploreTile(event: items[i]),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        '$e',
                        style: AppTextStyles.body(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopUpcomingHeader extends StatelessWidget {
  const _TopUpcomingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThin,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'LATEST EVENTS',
            style: AppTextStyles.display(
              20,
              color: AppColors.secondary,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreTile extends ConsumerStatefulWidget {
  const _ExploreTile({required this.event});

  final ExploreEvent event;

  @override
  ConsumerState<_ExploreTile> createState() => _ExploreTileState();
}

class _ExploreTileState extends ConsumerState<_ExploreTile> {
  late bool _inCalendar;
  bool _calendarBusy = false;

  @override
  void initState() {
    super.initState();
    _inCalendar = widget.event.inCalendar;
  }

  @override
  void didUpdateWidget(covariant _ExploreTile oldWidget) {
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
        final imageHeight = _ExploreTileLayout.imageHeight(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: imageHeight,
                  // width: double.infinity,
                  child: InkWell(
                    onTap: _openSheet,
                    child: Stack(
                      // fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Hero(
                            tag: event.heroTag,
                            child: Container(
                              padding: EdgeInsets.all(4),
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
                Expanded(
                  child: InkWell(
                    onTap: _openSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                          child: Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.display(
                              15,
                              color: AppColors.secondary,
                              letterSpacing: 0.02,
                            ),
                          ),
                        ),
                        if (placeShort.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            child: _MetaRow(
                              icon: Icons.place_outlined,
                              label: placeShort,
                            ),
                          ),
                        ],
                        if (dateLabel != null ||
                            (timeLabel != null && timeLabel.isNotEmpty)) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            child: _DateTimeRow(
                              date: dateLabel,
                              time: timeLabel,
                            ),
                          ),
                        ],
                        if (event.showAttendees || event.hasTicketUrl) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            child: DecoratedBox(
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
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${event.attendees}',
                                        style: AppTextStyles.body(
                                          13,
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
                          ),
                        ],
                        // Push calendar to card bottom without opening a hole
                        // between date and attendees.
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(4),
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
          width: _ExploreTileLayout.ticketButtonSize,
          height: _ExploreTileLayout.ticketButtonSize,
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
      height: _ExploreTileLayout.calendarHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          // border: const Border(
          //   top: BorderSide(
          //     color: AppColors.border,
          //     width: AppDimens.borderThick,
          //   ),
          // ),
        ),
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
