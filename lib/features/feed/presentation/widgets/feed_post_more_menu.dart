import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/post_more_menu_button.dart';
import 'feed_post_report_flow.dart';

class FeedPostMoreMenu extends ConsumerWidget {
  const FeedPostMoreMenu({
    super.key,
    required this.postId,
    this.isPast = false,
    this.isOwnPost = false,
  });

  final String postId;
  final bool isPast;

  /// Authors can mark their own upcoming events as cancelled.
  final bool isOwnPost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (postId.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.border, width: AppDimens.border),
      ),
      onSelected: (value) {
        final type = switch (value) {
          'event_cancelled' => FeedPostReportType.eventCancelled,
          'spam' => FeedPostReportType.spam,
          'bug' => FeedPostReportType.bug,
          _ => null,
        };
        if (type != null) {
          handleFeedPostReport(context: context, ref: ref, postId: postId, type: type);
        }
      },
      itemBuilder: (context) => [
        if (isOwnPost && !isPast)
          PopupMenuItem(
            value: 'event_cancelled',
            child: Text(
              'Event is cancelled',
              style: AppTextStyles.body(14, weight: FontWeight.w700),
            ),
          ),
        PopupMenuItem(
          value: 'spam',
          child: Text(
            'Spam event',
            style: AppTextStyles.body(14, weight: FontWeight.w700),
          ),
        ),
        PopupMenuItem(
          value: 'bug',
          child: Text(
            'Report a bug',
            style: AppTextStyles.body(14, weight: FontWeight.w700),
          ),
        ),
      ],
      child: const PostMoreMenuIcon(),
    );
  }
}
