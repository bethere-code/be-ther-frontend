import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/design/widgets/author_avatar.dart';
import '../../../core/routing/app_route_observer.dart';
import 'profile_providers.dart';
import 'profile_screen.dart';
import 'widgets/profile_private_notice.dart';
import 'widgets/profile_subpage_scaffold.dart';

export 'profile_providers.dart' show ProfileConnectionsMode;

/// Shared Followers / Following list — tap a row to open that profile.
class ProfileConnectionsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState
    extends ConsumerState<ProfileConnectionsScreen>
    with RouteAware {
  bool _routeSubscribed = false;
  bool _refreshing = false;

  ProfileConnectionsKey get _key =>
      (username: widget.username, mode: widget.mode);

  @override
  void initState() {
    super.initState();
    // Always fetch latest followers/following when opening this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_silentRefresh());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning from a nested profile (e.g. after unfollow) — soft API refresh.
    unawaited(_silentRefresh());
  }

  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // refresh keeps prior list visible (skipLoadingOnRefresh).
      final _ = await ref.refresh(profileConnectionsProvider(_key).future);
    } catch (_) {
      // Keep the current list if the background refresh fails.
    } finally {
      if (mounted) _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileViewProvider(widget.username));
    final waitingOnProfile = !profile.hasValue && !profile.hasError;
    final locked = profile.maybeWhen(
      data: isPrivateProfileLocked,
      orElse: () => false,
    );
    final async = ref.watch(profileConnectionsProvider(_key));
    final privateError = async.hasError && isPrivateProfileError(async.error!);
    final title = widget.mode == ProfileConnectionsMode.followers
        ? 'FOLLOWERS'
        : 'FOLLOWING';
    final isFollowers = widget.mode == ProfileConnectionsMode.followers;

    Widget child;
    if (locked || privateError) {
      child = ProfilePrivateNotice(
        detail: isFollowers
            ? 'Follow to see their followers.'
            : 'Follow to see who they follow.',
      );
    } else if (waitingOnProfile) {
      child = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else {
      child = async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
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
                  e is ApiException ? e.message : 'Could not load list',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(14, color: AppColors.foreground),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(profileConnectionsProvider(_key)),
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
                widget.mode == ProfileConnectionsMode.followers
                    ? 'No followers yet'
                    : 'Not following anyone yet',
                style: AppTextStyles.body(15, color: AppColors.mutedForeground),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: _silentRefresh,
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
                          bottom: BorderSide(color: AppColors.border, width: 1),
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
      );
    }

    return ProfileSubpageScaffold(
      title: title,
      subtitle: '@${widget.username}',
      child: child,
    );
  }
}
