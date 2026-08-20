import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_ther/core/ui/app_toast.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/post_more_menu_button.dart';
import '../../../explore/presentation/explore_providers.dart';
import '../../../notifications/presentation/notifications_providers.dart';
import '../../../profile/presentation/block_session.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../calendar_status_store.dart';
import '../feed_providers.dart';
import 'feed_post_more_menu_kind.dart';
import 'feed_post_report_flow.dart';

export 'feed_post_more_menu_kind.dart';

class FeedPostMoreMenu extends ConsumerWidget {
  const FeedPostMoreMenu({
    super.key,
    required this.postId,
    this.isPast = false,
    this.isOwnPost = false,
    this.authorUsername = '',
  });

  final String postId;
  final bool isPast;
  final bool isOwnPost;
  final String authorUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (postId.isEmpty) return const SizedBox.shrink();

    final kind = resolveFeedPostMoreMenu(isOwnPost: isOwnPost, isPast: isPast);
    if (kind == FeedPostMoreMenuKind.none) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(
          color: AppColors.border,
          width: AppDimens.border,
        ),
      ),
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => _items(kind),
      child: const PostMoreMenuIcon(),
    );
  }

  List<PopupMenuEntry<String>> _items(FeedPostMoreMenuKind kind) {
    Text label(String text, {Color? color}) => Text(
      text,
      style: AppTextStyles.body(14, weight: FontWeight.w700, color: color),
    );

    switch (kind) {
      case FeedPostMoreMenuKind.none:
        return const [];
      case FeedPostMoreMenuKind.ownUpcoming:
        return [
          PopupMenuItem(value: 'edit', child: label('Edit')),
          PopupMenuItem(
            value: 'delete',
            child: label('Delete', color: AppColors.destructive),
          ),
          PopupMenuItem(
            value: 'event_cancelled',
            child: label('Event is cancelled'),
          ),
        ];
      case FeedPostMoreMenuKind.ownPast:
        return [
          PopupMenuItem(value: 'edit', child: label('Edit')),
          PopupMenuItem(
            value: 'delete',
            child: label('Delete', color: AppColors.destructive),
          ),
        ];
      case FeedPostMoreMenuKind.otherUpcoming:
        return [
          PopupMenuItem(value: 'report', child: label('Report event')),
          PopupMenuItem(
            value: 'block',
            child: label('Block user', color: AppColors.destructive),
          ),
        ];
    }
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    switch (value) {
      case 'edit':
        AppToast.show(context, 'Edit coming soon');
      case 'delete':
        await _confirmDelete(context, ref);
      case 'event_cancelled':
        await handleFeedPostReport(
          context: context,
          ref: ref,
          postId: postId,
          type: FeedPostReportType.eventCancelled,
        );
      case 'report':
        await handleFeedPostReport(
          context: context,
          ref: ref,
          postId: postId,
          type: FeedPostReportType.spam,
        );
      case 'block':
        await _confirmBlock(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(postsRepositoryProvider).deletePost(postId);
      ref.read(deletedPostIdsProvider.notifier).markDeleted(postId);
      ref.read(calendarStatusStoreProvider.notifier).setStatus(postId, null);
      ref.invalidate(exploreEventsProvider);
      ref.invalidate(profileMeProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (!context.mounted) return;
      AppToast.show(context, 'Event deleted');
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final username = authorUsername.trim();
    if (username.isEmpty) return;
    final label = '@$username';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'BLOCK $label?',
          style: AppTextStyles.display(20, color: AppColors.secondary),
        ),
        content: Text(
          'You will unfollow them. Their events will no longer appear in feed, explore, or search.',
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
            child: const Text('BLOCK'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await blockUserOptimistic(ref, username);
      if (!context.mounted) return;
      AppToast.show(context, 'User blocked');
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
