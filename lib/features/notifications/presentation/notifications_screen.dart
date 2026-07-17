import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../profile/presentation/profile_screen.dart';
import 'notifications_providers.dart';
import 'widgets/notification_list_tile.dart';
import 'widgets/notification_post_sheet.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static const path = '/notifications';
  static const name = 'notifications';

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Badge clears on next successful refresh; avoid blocking the screen.
    }
  }

  static void _showMessagesInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'MESSAGES',
          style: AppTextStyles.display(22, color: AppColors.secondary),
        ),
        content: Text(
          'Direct messages are available when you and another user star each other. Coming in a future update.',
          style: AppTextStyles.body(15, color: AppColors.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotification({
    required BuildContext context,
    required Map<String, dynamic> n,
  }) async {
    final actor = n['actorUserId'] is Map<String, dynamic>
        ? n['actorUserId'] as Map<String, dynamic>
        : <String, dynamic>{};
    final username = actor['username'] as String? ?? '';
    final type = n['type'] as String? ?? 'star';
    final post = n['postId'] is Map<String, dynamic>
        ? n['postId'] as Map<String, dynamic>
        : null;

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
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider);

    return AppShell(
      activeTab: ShellTab.notifications,
      showRail: true,
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
              // Matches Figma Make header spacer (no avatar in alerts header).
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: Text(
                    'ALERTS',
                    style: AppTextStyles.display(
                      28,
                      color: AppColors.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showMessagesInfo(context),
                icon: const Icon(
                  Icons.mail_outline,
                  color: AppColors.background,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
      child: ColoredBox(
        color: AppColors.background,
        child: list.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: AppTextStyles.body(
                        15.2,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
                await ref.read(notificationsProvider.future);
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                // Full-width rows; right rail floats over content (Figma Make).
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final n = items[i];
                  return NotificationListTile(
                    notification: n,
                    onOpen: () => _openNotification(
                      context: context,
                      n: n,
                    ),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    '$e',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      14,
                      color: AppColors.foreground,
                    ),
                  ),
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
      ),
    );
  }
}
