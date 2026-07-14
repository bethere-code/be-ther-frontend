import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../../core/design/widgets/shell_header_avatar.dart';
import '../../profile/presentation/profile_screen.dart';
import 'notifications_providers.dart';
import 'widgets/notification_post_sheet.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const path = '/notifications';
  static const name = 'notifications';

  static String _messageForType(String type) {
    switch (type) {
      case 'wishlist':
        return ' saved your event to their wishlist';
      case 'calendar':
        return ' added your event to their calendar';
      case 'star':
      default:
        return ' starred your profile';
    }
  }

  static void _showMessagesInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('MESSAGES', style: AppTextStyles.display(22, color: AppColors.secondary)),
        content: const Text(
          'Direct messages are available when you and another user star each other. Coming in a future update.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);

    return AppShell(
      activeTab: ShellTab.notifications,
      header: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
          ),
          child: Row(
            children: [
              const ShellHeaderAvatar(),
              Expanded(
                child: Center(
                  child: Text('ALERTS', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.1)),
                ),
              ),
              IconButton(
                onPressed: () => _showMessagesInfo(context),
                icon: const Icon(Icons.mail_outline, color: AppColors.background),
              ),
            ],
          ),
        ),
      ),
      child: list.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('No notifications yet', style: AppTextStyles.body(16, color: AppColors.mutedForeground)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                final read = n['read'] as bool? ?? true;
                final actor = n['actorUserId'] is Map<String, dynamic> ? n['actorUserId'] as Map<String, dynamic> : <String, dynamic>{};
                final name = actor['displayName'] as String? ?? actor['username'] as String? ?? 'User';
                final username = actor['username'] as String? ?? '';
                final avatar = actor['avatarUrl'] as String? ?? '';
                final type = n['type'] as String? ?? 'star';
                final id = n['_id']?.toString() ?? '';
                final mutual = n['mutualStar'] as bool? ?? false;
                final post = n['postId'] is Map<String, dynamic> ? n['postId'] as Map<String, dynamic> : null;
                final postImage = post?['imageUrl'] as String? ?? '';

                return InkWell(
                  onTap: () async {
                    if (!read && id.isNotEmpty) {
                      await ref.read(notificationsRepositoryProvider).markRead(id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    }
                    if (!context.mounted) return;
                    if (type == 'star' && username.isNotEmpty) {
                      context.push(ProfileScreen.pathForUser(username));
                      return;
                    }
                    if (post != null && post.isNotEmpty) {
                      await showNotificationPostSheet(
                        context: context,
                        post: post,
                        actorUsername: username,
                      );
                    } else if (username.isNotEmpty) {
                      context.push(ProfileScreen.pathForUser(username));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: read ? AppColors.card : AppColors.primary.withValues(alpha: 0.06),
                      border: const Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthorAvatar(
                          avatarUrl: avatar,
                          username: username,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: name, style: AppTextStyles.body(15, weight: FontWeight.w800)),
                                    TextSpan(
                                      text: _messageForType(type),
                                      style: AppTextStyles.body(15),
                                    ),
                                  ],
                                ),
                              ),
                              if (mutual && type == 'star') ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: AppColors.accent,
                                  child: Text(
                                    'MUTUAL',
                                    style: AppTextStyles.display(10, color: AppColors.accentForeground),
                                  ),
                                ),
                              ],
                              if (!read) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: AppColors.primary,
                                  child: Text(
                                    'NEW',
                                    style: AppTextStyles.display(10, color: AppColors.primaryForeground),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (postImage.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: AppDimens.border)),
                            clipBehavior: Clip.hardEdge,
                            child: BeTherNetworkImage(url: postImage, fit: BoxFit.cover),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
