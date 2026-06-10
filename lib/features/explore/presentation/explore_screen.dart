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
import '../../search/presentation/search_screen.dart';
import 'explore_providers.dart';
import 'widgets/explore_event_sheet.dart';

/// Shared sizes so grid [childAspectRatio] matches tile content exactly.
abstract final class _ExploreTileLayout {
  static const double calendarHeight = 36;
  // 10 top + 8 bottom
  // 2 lines @ display 15
  static const double metaRowHeight = 16;
  static const double metaGap = 4;
  static const double attendeesBlockHeight = 26; // divider + row

  static double imageHeight(double tileWidth) => tileWidth * 5 / 5;
}

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const path = '/explore';
  static const name = 'explore';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(exploreEventsProvider);

    return AppShell(
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
                    onRefresh: () => ref.refresh(exploreEventsProvider.future),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 9 / 16.6,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, i) =>
                              _ExploreTile(event: items[i]),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText('$e', style: AppTextStyles.body(14)),
                  ),
                ),
              ),
            ),
          ],
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

  final Map<String, dynamic> event;

  @override
  ConsumerState<_ExploreTile> createState() => _ExploreTileState();
}

class _ExploreTileState extends ConsumerState<_ExploreTile> {
  late bool _inCalendar;
  bool _calendarBusy = false;

  @override
  void initState() {
    super.initState();
    _inCalendar = widget.event['inCalendar'] as bool? ?? false;
  }

  @override
  void didUpdateWidget(covariant _ExploreTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event['inCalendar'] != widget.event['inCalendar']) {
      _inCalendar = widget.event['inCalendar'] as bool? ?? false;
    }
  }

  Future<void> _toggleCalendar(String postId) async {
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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final title = event['title'] as String? ?? '';
    final location = event['location'] as String? ?? '';
    final date = event['date'] as String? ?? '';
    final image =
        event['image'] as String? ?? event['imageUrl'] as String? ?? '';
    final postId =
        event['postId']?.toString() ?? event['_id']?.toString() ?? '';
    final attendees = event['attendees'] as int? ?? 0;
    final trending = event['trending'] as bool? ?? false;
    final ticketUrl = event['ticketUrl'] as String?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final imageHeight = _ExploreTileLayout.imageHeight(cardWidth);
        print('cardWidth: $cardWidth, imageHeight: $imageHeight');
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Material(
                  color: AppColors.card,
                  child: InkWell(
                    onTap: postId.isEmpty
                        ? null
                        : () => showExploreEventSheet(
                            context: context,
                            event: event,
                          ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BeTherNetworkImage(url: image, fit: BoxFit.cover),
                        if (trending)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: AppColors.accentForeground,
                                  ),
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
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                // height: _ExploreTileLayout.footerHeight,
                child: Column(
                  // crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      // height: _ExploreTileLayout.detailsSectionHeight,
                      child: Material(
                        color: AppColors.card,
                        child: InkWell(
                          onTap: postId.isEmpty
                              ? null
                              : () => showExploreEventSheet(
                                  context: context,
                                  event: event,
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
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    // height: _ExploreTileLayout.titleBlockHeight,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.display(
                                          15,
                                          color: AppColors.secondary,
                                          letterSpacing: 0.02,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: _ExploreTileLayout.metaRowHeight,
                                    child: _MetaRow(
                                      icon: Icons.place_outlined,
                                      label: location,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: _ExploreTileLayout.metaGap,
                                  ),
                                  SizedBox(
                                    height: _ExploreTileLayout.metaRowHeight,
                                    child: _MetaRow(
                                      icon: Icons.calendar_today_outlined,
                                      label: date,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height:
                                        _ExploreTileLayout.attendeesBlockHeight,
                                    child: Container(
                                      padding: const EdgeInsets.only(top: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: AppColors.border,
                                            width: AppDimens.borderThinnest,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$attendees',
                                            style: AppTextStyles.body(
                                              12,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (ticketUrl != null &&
                                              ticketUrl.trim().isNotEmpty)
                                            GestureDetector(
                                              onTap: () => openExternalUrl(
                                                context,
                                                ticketUrl,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  border: Border.all(
                                                    color: AppColors.border,
                                                    width: AppDimens.borderThin,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.open_in_new,
                                                  size: 13,
                                                  color: AppColors
                                                      .accentForeground,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _ExploreCalendarButton(
                      inCalendar: _inCalendar,
                      loading: _calendarBusy,
                      onPressed: postId.isEmpty
                          ? null
                          : () => _toggleCalendar(postId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, this.fontSize = 12});

  final IconData icon;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize,
              color: AppColors.mutedForeground,
              weight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width footer flush with the card border — no side gaps.
class _ExploreCalendarButton extends StatelessWidget {
  const _ExploreCalendarButton({
    required this.inCalendar,
    required this.loading,
    required this.onPressed,
  });

  final bool inCalendar;
  final bool loading;
  final VoidCallback? onPressed;

  static const double _height = _ExploreTileLayout.calendarHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Material(
        color: inCalendar ? AppColors.primary : AppColors.accent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: AppDimens.borderThick,
                ),
              ),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: inCalendar
                            ? AppColors.primaryForeground
                            : AppColors.accentForeground,
                      ),
                    )
                  : Text(
                      inCalendar ? 'ADDED' : 'ADD TO CALENDAR',
                      style: AppTextStyles.display(
                        11,
                        color: inCalendar
                            ? AppColors.primaryForeground
                            : AppColors.accentForeground,
                        letterSpacing: 0.05,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
