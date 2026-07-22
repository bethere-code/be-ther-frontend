import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../profile/presentation/profile_screen.dart';
import 'notification_post_sheet.dart';

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    super.key,
    required this.notification,
    required this.onOpen,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onOpen;

  static String messageForType(String type) {
    switch (type) {
      case 'wishlist':
        return ' added your event to their wishlist';
      case 'calendar':
        return ' added your event to their calendar';
      case 'follow':
      case 'star': // legacy
      default:
        return ' started following you';
    }
  }

  static String? _formatEventDate(Map<String, dynamic>? post) {
    if (post == null) return null;
    final details = post['eventDetails'] as Map<String, dynamic>?;
    final raw = details?['date'] as String?;
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.length >= 10) {
      final iso = DateTime.tryParse(trimmed.substring(0, 10));
      if (iso != null) return DateFormat('MMM d, y').format(iso);
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return DateFormat('MMM d, y').format(parsed);
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final read = notification['read'] as bool? ?? true;
    final actor = notification['actorUserId'] is Map<String, dynamic>
        ? notification['actorUserId'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name = actor['displayName'] as String? ??
        actor['username'] as String? ??
        'User';
    final username = actor['username'] as String? ?? '';
    final avatar = actor['avatarUrl'] as String? ?? '';
    final badge = actor['badge'] as String?;
    final type = notification['type'] as String? ?? 'follow';
    final mutual = notification['mutualFollow'] as bool? ??
        notification['mutualStar'] as bool? ??
        false;
    final post = notification['postId'] is Map<String, dynamic>
        ? notification['postId'] as Map<String, dynamic>
        : null;
    final postImage = post?['imageUrl'] as String? ?? '';
    final eventTitle = post?['location'] as String? ?? '';
    final eventDate = _formatEventDate(post);
    final createdAt = DateTime.tryParse(
      notification['createdAt']?.toString() ?? '',
    );
    final timestamp =
        createdAt != null ? getRelativeTime(createdAt) : '';

    // Opaque unread tint over cream/card — never translucent over navy shell.
    final rowColor = read
        ? AppColors.card
        : Color.lerp(AppColors.card, AppColors.primary, 0.05)!;

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border,
                width: AppDimens.borderThick,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthorAvatar(
                avatarUrl: avatar,
                username: username,
                badge: badge,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: name,
                                  style: AppTextStyles.body(
                                    15.2,
                                    weight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                TextSpan(
                                  text: messageForType(type),
                                  style: AppTextStyles.body(
                                    15.2,
                                    weight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (timestamp.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timestamp,
                            style: AppTextStyles.body(
                              12,
                              weight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (type == 'follow' || type == 'star') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const _StarChip(
                            label: 'NEW FOLLOW',
                            background: AppColors.accent,
                            foreground: AppColors.accentForeground,
                          ),
                          if (mutual)
                            const _StarChip(
                              label: 'MUTUAL',
                              background: AppColors.primary,
                              foreground: AppColors.primaryForeground,
                            ),
                        ],
                      ),
                    ],
                    if ((type == 'wishlist' || type == 'calendar') &&
                        post != null) ...[
                      const SizedBox(height: 8),
                      _EventSnippet(
                        title: eventTitle.isNotEmpty ? eventTitle : 'Event',
                        dateLabel: eventDate,
                        imageUrl: postImage,
                        kind: type,
                        onTap: () => showNotificationPostSheet(
                          context: context,
                          post: post,
                          actorUsername: username,
                        ),
                      ),
                    ],
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            context.push(ProfileScreen.pathForUser(username)),
                        child: Text(
                          'View @$username',
                          style: AppTextStyles.body(
                            13.6,
                            weight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.display(
              12,
              color: foreground,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSnippet extends StatelessWidget {
  const _EventSnippet({
    required this.title,
    required this.dateLabel,
    required this.imageUrl,
    required this.kind,
    required this.onTap,
  });

  final String title;
  final String? dateLabel;
  final String imageUrl;
  final String kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = kind == 'calendar' ? 'CALENDARED' : 'WISHLISTED';
    final statusIcon =
        kind == 'calendar' ? Icons.calendar_today : Icons.bookmark_border;

    return Material(
      color: AppColors.muted,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(
                    color: AppColors.border,
                    width: AppDimens.borderThin,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: imageUrl.isNotEmpty
                    ? BeTherNetworkImage(url: imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.image, color: AppColors.mutedForeground),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display(
                        14.4,
                        color: AppColors.secondary,
                        letterSpacing: 0.02,
                      ),
                    ),
                    if (dateLabel != null && dateLabel!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateLabel!,
                              style: AppTextStyles.body(
                                12,
                                weight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: AppTextStyles.display(
                            11.2,
                            color: AppColors.primary,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
