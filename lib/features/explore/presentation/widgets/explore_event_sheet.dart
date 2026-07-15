import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../feed/presentation/feed_providers.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../../domain/explore_event.dart';

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
  late bool _inCalendar;
  bool _calendarBusy = false;

  ExploreEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _inCalendar = event.inCalendar;
  }

  bool _isMine(Map<String, dynamic>? me) {
    final author = event.author;
    if (me == null || author == null) return false;
    final myId = me['_id']?.toString();
    if (myId != null &&
        myId.isNotEmpty &&
        author.id.isNotEmpty &&
        myId == author.id) {
      return true;
    }
    final myUsername = me['username'] as String? ?? '';
    return myUsername.isNotEmpty && myUsername == author.username;
  }

  Future<void> _toggleCalendar() async {
    if (event.postId.isEmpty || _calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final next = await ref
          .read(postsRepositoryProvider)
          .toggleCalendar(event.postId);
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
    final isMine = _isMine(me);
    final author = event.author;
    final place = event.placeLabel;
    final dateLabel = event.formattedDateOnly;
    final timeLabel = event.time;
    final headerLabel = !isMine && (author?.username.isNotEmpty ?? false)
        ? '@${author!.username}'
        : 'EVENT DETAILS';

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
                        child: Text(
                          headerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.display(
                            20,
                            color: AppColors.primary,
                            letterSpacing: 0.05,
                          ),
                        ),
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
                            if (timeLabel != null)
                              _MetaChip(
                                icon: Icons.access_time,
                                label: timeLabel,
                              ),
                            if (event.showAttendees)
                              _MetaChip(
                                icon: Icons.person_outline,
                                label: '${event.attendees} going',
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
                              onPressed: _calendarBusy ? null : _toggleCalendar,
                              child: _calendarBusy
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
                  if (!isMine &&
                      author != null &&
                      author.username.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.card,
                      child: InkWell(
                        onTap: _openCreatorProfile,
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
                          onPressed: () =>
                              openExternalUrl(context, event.ticketUrl!),
                          icon: const Icon(Icons.link),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
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
