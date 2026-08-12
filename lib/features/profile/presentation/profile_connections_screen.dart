import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/author_avatar.dart';
import 'profile_providers.dart';
import 'profile_screen.dart';
import 'widgets/profile_subpage_scaffold.dart';

export 'profile_providers.dart' show ProfileConnectionsMode;

/// Shared Followers / Following list — tap a row to open that profile.
class ProfileConnectionsScreen extends ConsumerWidget {
  const ProfileConnectionsScreen({
    super.key,
    required this.username,
    required this.mode,
  });

  final String username;
  final ProfileConnectionsMode mode;

  static String followersPath(String username) =>
      '/profile/$username/followers';
  static String followingPath(String username) =>
      '/profile/$username/following';
  static const followersName = 'profile-followers';
  static const followingName = 'profile-following';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      profileConnectionsProvider((username: username, mode: mode)),
    );
    final title = mode == ProfileConnectionsMode.followers
        ? 'FOLLOWERS'
        : 'FOLLOWING';

    return ProfileSubpageScaffold(
      title: title,
      subtitle: '@$username',
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  '$e',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(14, color: AppColors.foreground),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(
                    profileConnectionsProvider((
                      username: username,
                      mode: mode,
                    )),
                  ),
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                mode == ProfileConnectionsMode.followers
                    ? 'No followers yet'
                    : 'Not following anyone yet',
                style: AppTextStyles.body(
                  15,
                  color: AppColors.mutedForeground,
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              final key = (username: username, mode: mode);
              ref.invalidate(profileConnectionsProvider(key));
              await ref.read(profileConnectionsProvider(key).future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final user = items[i];
                return Material(
                  color: AppColors.card,
                  child: InkWell(
                    onTap: user.username.isEmpty
                        ? null
                        : () => context.push(
                              ProfileScreen.pathForUser(user.username),
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: AppDimens.borderThick,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          AuthorAvatar(
                            avatarUrl: user.avatarUrl,
                            username: user.username,
                            size: 48,
                            interactive: false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(
                                    15,
                                    weight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                if (user.username.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${user.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(
                                      13,
                                      weight: FontWeight.w600,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
