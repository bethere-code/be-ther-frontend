import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/app_shell.dart';
import '../../../core/design/widgets/be_ther_network_image.dart';
import '../../profile/presentation/profile_screen.dart';
import 'notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const path = '/notifications';
  static const name = 'notifications';

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
              InkWell(
                onTap: () => context.push(ProfileScreen.path),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: AppDimens.borderThick),
                    color: AppColors.muted,
                  ),
                  child: const Icon(Icons.person, color: AppColors.background),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('ALERTS', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.1)),
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.mail_outline, color: AppColors.background)),
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
            onRefresh: () => ref.refresh(notificationsProvider.future),
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

                return InkWell(
                  onTap: () async {
                    if (!read && id.isNotEmpty) {
                      await ref.read(notificationsRepositoryProvider).markRead(id);
                      ref.invalidate(notificationsProvider);
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: AppDimens.border)),
                          clipBehavior: Clip.hardEdge,
                          child: avatar.isNotEmpty
                              ? BeTherNetworkImage(url: avatar, fit: BoxFit.cover)
                              : Icon(Icons.person, color: AppColors.foreground),
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
                                      text: type == 'star' ? ' starred your profile' : ' interacted with your content',
                                      style: AppTextStyles.body(15),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(ProfileScreen.path),
                                child: Text('View @$username', style: AppTextStyles.body(13, color: AppColors.primary, weight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('$e')),
      ),
    );
  }
}
