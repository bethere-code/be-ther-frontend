import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../feed/presentation/widgets/feed_post_card.dart';
import 'profile_providers.dart';
import 'widgets/profile_private_notice.dart';
import 'widgets/profile_subpage_scaffold.dart';

/// Authored events for a profile user — feed-style cards.
class ProfileEventsScreen extends ConsumerWidget {
  const ProfileEventsScreen({super.key, required this.username});

  final String username;

  static String pathFor(String username) => '/profile/$username/events';
  static const name = 'profile-events';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileViewProvider(username));
    final waitingOnProfile = !profile.hasValue && !profile.hasError;
    final locked = profile.maybeWhen(
      data: isPrivateProfileLocked,
      orElse: () => false,
    );
    final async = ref.watch(profileEventsProvider(username));
    final privateError =
        async.hasError && isPrivateProfileError(async.error!);

    Widget child;
    if (locked || privateError) {
      child = const ProfilePrivateNotice(
        detail: 'Follow each other to view their events.',
      );
    } else if (waitingOnProfile) {
      child = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else {
      child = async.when(
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
                      Text(
                        e is ApiException ? e.message : 'Could not load events',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(14, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(profileEventsProvider(username)),
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
                      'No events yet',
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
                    ref.invalidate(profileEventsProvider(username));
                    await ref.read(profileEventsProvider(username).future);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      return FeedPostCard(
                        item: items[i],
                        recordFeedImpression: false,
                      );
                    },
                  ),
                );
              },
            );
    }

    return ProfileSubpageScaffold(
      title: 'EVENTS',
      subtitle: '@$username',
      child: child,
    );
  }
}
