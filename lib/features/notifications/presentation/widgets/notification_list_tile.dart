import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../profile/presentation/profile_screen.dart';

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

  static String? _formatEventTime(Map<String, dynamic>? post) {
    if (post == null) return null;
    final details = post['eventDetails'] as Map<String, dynamic>?;
    return EventDateUtils.formatTime12h(details?['time']?.toString());
  }

  @override
  Widget build(BuildContext context) {
    final read = notification['read'] as bool? ?? true;
    final actor = notification['actorUserId'] is Map<String, dynamic>
        ? notification['actorUserId'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name =
        actor['displayName'] as String? ??
        actor['username'] as String? ??
        'User';
    final username = actor['username'] as String? ?? '';
    final avatar = actor['avatarUrl'] as String? ?? '';
    final badge = actor['badge'] as String?;
    final type = notification['type'] as String? ?? 'follow';
    final post = notification['postId'] is Map<String, dynamic>
        ? notification['postId'] as Map<String, dynamic>
        : null;
    final postImage = post?['imageUrl'] as String? ?? '';
    final eventTitle = post?['location'] as String? ?? '';
    final eventDate = _formatEventDate(post);
    final eventTime = _formatEventTime(post);
    final hasEvent = (type == 'wishlist' || type == 'calendar') && post != null;
    final createdAt = DateTime.tryParse(
      notification['createdAt']?.toString() ?? '',
    );
    final timestamp = createdAt != null ? getRelativeTime(createdAt) : '';

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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: hasEvent
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
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
                    if (hasEvent) ...[
                      const SizedBox(height: 8),
                      _EventSnippet(
                        title: eventTitle.isNotEmpty ? eventTitle : 'Event',
                        dateLabel: eventDate,
                        timeLabel: eventTime,
                        imageUrl: postImage,
                        onTap: onOpen,
                      ),
                    ],
                    // Profile link only for event notifications (not follows).
                    if (hasEvent && username.isNotEmpty) ...[
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

class _EventSnippet extends StatelessWidget {
  const _EventSnippet({
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String? dateLabel;
  final String? timeLabel;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    if (timeLabel != null && timeLabel!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeLabel!,
                            style: AppTextStyles.body(
                              12,
                              weight: FontWeight.w700,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
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
