import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/post_interaction_row.dart';
import '../../../core/design/widgets/post_skeleton.dart';
import '../../../core/utils/event_date_utils.dart';
import '../../../core/utils/link_utils.dart';
import '../../../core/utils/post_author.dart';
import '../../../core/utils/time_utils.dart';
import '../../feed/presentation/feed_providers.dart';

class SharedEventScreen extends ConsumerWidget {
  const SharedEventScreen({super.key, required this.postId});

  final String postId;

  static const path = '/event/:postId';
  static const name = 'shared-event';

  static String pathFor(String id) => '/event/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostProvider(postId));

    return AppShell(
      activeTab: ShellTab.home,
      child: postAsync.when(
        loading: () => const PostSkeleton(),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onBack: () => context.go('/feed'),
        ),
        data: (item) => _SharedEventBody(item: item),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              'Event unavailable',
              style: AppTextStyles.display(20, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onBack, child: const Text('BACK TO FEED')),
          ],
        ),
      ),
    );
  }
}

class _SharedEventBody extends StatelessWidget {
  const _SharedEventBody({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final author = readPostAuthor(item);
    final name =
        author['displayName'] as String? ??
        author['username'] as String? ??
        'User';
    final username = author['username'] as String? ?? '';
    final avatar = author['avatarUrl'] as String? ?? '';
    final badge = postAuthorBadge(item);
    final location = item['location'] as String? ?? '';
    final imageUrl = item['imageUrl'] as String? ?? '';
    final caption = item['caption'] as String? ?? '';
    final likes = item['likesCount'] as int? ?? 0;
    final comments = item['commentsCount'] as int? ?? 0;
    final id = item['_id']?.toString() ?? '';
    final liked = item['liked'] as bool? ?? false;
    final details = item['eventDetails'] as Map<String, dynamic>?;
    final ticketUrl = details?['ticketUrl'] as String?;
    final isPast = EventDateUtils.isPostPast(item);
    final createdAt = item['createdAt'] as String?;
    final timestamp = DateTime.tryParse(createdAt ?? '') ?? DateTime.now();
    final relativeTime = getRelativeTime(timestamp);
    final dateRaw = details?['date'] as String?;
    final timeRaw = details?['time'] as String?;
    final venue = details?['venue'] as String?;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AuthorAvatar(
                avatarUrl: avatar,
                username: username,
                badge: badge,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.body(15, weight: FontWeight.w800),
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
            ],
          ),
        ),
        if (imageUrl.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 10,
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
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(caption, style: AppTextStyles.body(15)),
          ),
        if (details != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _EventMeta(
              isPast: isPast,
              dateRaw: dateRaw,
              timeRaw: timeRaw,
              venue: venue,
              ticketUrl: ticketUrl,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: PostInteractionRow(
            postId: id,
            liked: liked,
            likesCount: likes,
            commentsCount: comments,
            location: location,
            caption: caption,
            ticketUrl: ticketUrl,
            imageUrl: imageUrl,
          ),
        ),
      ],
    );
  }
}

class _EventMeta extends StatelessWidget {
  const _EventMeta({
    required this.isPast,
    this.dateRaw,
    this.timeRaw,
    this.venue,
    this.ticketUrl,
  });

  final bool isPast;
  final String? dateRaw;
  final String? timeRaw;
  final String? venue;
  final String? ticketUrl;

  @override
  Widget build(BuildContext context) {
    final displayDate = _formatDate(dateRaw);
    final displayTime = timeRaw?.trim();
    final displayVenue = venue?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: AppDimens.border),
          bottom: BorderSide(color: AppColors.border, width: AppDimens.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayDate != null)
            Text('Date: $displayDate', style: AppTextStyles.body(14)),
          if (displayTime != null && displayTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Time: $displayTime', style: AppTextStyles.body(14)),
          ],
          if (displayVenue != null && displayVenue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Venue: $displayVenue', style: AppTextStyles.body(14)),
          ],
          const SizedBox(height: 12),
          if (isPast)
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
            )
          else if (ticketUrl != null && ticketUrl!.trim().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => openExternalUrl(context, ticketUrl),
                child: const Text('GET TICKETS'),
              ),
            ),
        ],
      ),
    );
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim().substring(0, raw.length >= 10 ? 10 : raw.length));
    if (parsed != null) return DateFormat('d MMM y').format(parsed);
    return raw.trim();
  }
}
