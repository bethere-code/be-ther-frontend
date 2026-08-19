import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/network/api_exception.dart';
import '../../explore/presentation/explore_providers.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../profile/domain/profile_user.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../profile/presentation/widgets/profile_subpage_scaffold.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  static const path = '/settings/blocked';
  static const name = 'settings-blocked';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);

    return ProfileSubpageScaffold(
      title: 'BLOCKED',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          if (_isMissingList(e)) {
            return const _BlockedListShell(child: _BlockedEmpty());
          }
          return _BlockedListShell(
            child: _BlockedLoadError(
              onRetry: () => ref.invalidate(blockedUsersProvider),
            ),
          );
        },
        data: (items) {
          return _BlockedListShell(
            child: items.isEmpty
                ? const _BlockedEmpty()
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final user = items[i];
                      return Material(
                        color: AppColors.card,
                        child: InkWell(
                          onTap: user.username.isEmpty
                              ? null
                              : () => _confirmUnblock(context, ref, user),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border,
                                  width: 1,
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
                                Text(
                                  'UNBLOCK',
                                  style: AppTextStyles.display(
                                    11,
                                    color: AppColors.primary,
                                    letterSpacing: 0.06,
                                  ),
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

bool _isMissingList(Object error) {
  if (error is ApiException && error.statusCode == 404) return true;
  final text = error.toString().toLowerCase();
  return text == 'not found' || (text.contains('route') && text.contains('not found'));
}

class _BlockedListShell extends StatelessWidget {
  const _BlockedListShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Tap a person to unblock them. Their public events can show in feed, explore, and search again.',
            style: AppTextStyles.body(
              14,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        Expanded(child: child),
      ],
    );
  }
}

class _BlockedEmpty extends StatelessWidget {
  const _BlockedEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.muted,
                border: Border.all(color: AppColors.border, width: AppDimens.border),
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 40,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'NOBODY BLOCKED',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(28, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Text(
              'Accounts you block will show up here. You can unblock them anytime.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(15, color: AppColors.mutedForeground, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedLoadError extends StatelessWidget {
  const _BlockedLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40, color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              'COULD NOT LOAD',
              style: AppTextStyles.display(24, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(15, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmUnblock(
  BuildContext context,
  WidgetRef ref,
  ProfileConnectionUser user,
) async {
  final label = user.username.isNotEmpty ? '@${user.username}' : user.displayName;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        'UNBLOCK?',
        style: AppTextStyles.display(22, color: AppColors.secondary),
      ),
      content: Text(
        'Unblock $label? They can see your public events again and may follow you.',
        style: AppTextStyles.body(15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('UNBLOCK'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    await ref.read(userRepositoryProvider).setBlocked(user.username, blocked: false);
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(profileViewProvider(user.username));
    ref.invalidate(feedProvider);
    ref.invalidate(exploreEventsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label unblocked')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}
