import 'package:be_ther/features/feed/presentation/add_post_screen.dart';
import 'package:be_ther/features/feed/presentation/feed_screen.dart';
import 'package:be_ther/features/notifications/presentation/notifications_screen.dart';
import 'package:be_ther/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/auth_notifier.dart';
import '../../../features/notifications/presentation/notifications_providers.dart';
import '../../../features/profile/presentation/profile_providers.dart';
import '../../utils/badge_colors.dart';
import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_images.dart';
import '../app_text_styles.dart';
import 'be_ther_network_image.dart';

enum ShellTab { home, add, notifications, explore }

/// Bottom brand row + right vertical rail matching Figma Make layout.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.activeTab,
    this.showRail = true,
    this.showBottomBar = true,
    this.header,
  });

  final Widget child;
  final ShellTab activeTab;
  final bool showRail;
  final bool showBottomBar;
  final PreferredSizeWidget? header;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                ?header,
                Expanded(child: child),
                if (showBottomBar) _BottomBar(activeTab: activeTab),
              ],
            ),
            if (showRail)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _RightRail(activeTab: activeTab),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.activeTab});

  final ShellTab activeTab;

  static const double _horizontalPadding = 16;
  static const double _verticalPadding = 10;
  static const double _leadingHeight = 40;

  static bool _isProfileRoute(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path == ProfileScreen.path || path.startsWith('${ProfileScreen.path}/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    final me = ref.watch(profileMeProvider);
    final badge = me.value?['badge'] as String? ?? user?['badge'] as String?;
    final onProfile = _isProfileRoute(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding,
        _verticalPadding,
        _horizontalPadding,
        _verticalPadding + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderThick,
          ),
        ),
      ),
      child: Row(
        children: [
          if (onProfile)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(FeedScreen.path),
                child: SizedBox(
                  height: _leadingHeight,
                  child: Image.asset(
                    AppImages.beatherLogo,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else if (user != null)
            GestureDetector(
              onTap: () => context.push(ProfileScreen.path),
              child: Container(
                width: _leadingHeight,
                height: _leadingHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: badgeBorderColor(badge),
                    width: AppDimens.borderThick,
                  ),
                  color: AppColors.muted,
                ),
                clipBehavior: Clip.hardEdge,
                child: user['avatarUrl'] != null && user['avatarUrl'].isNotEmpty
                    ? BeTherNetworkImage(
                        url: user['avatarUrl'],
                        fit: BoxFit.cover,
                      )
                    : Icon(Icons.person, color: AppColors.background),
              ),
            )
          else
            Text(
              'BE THER',
              style: AppTextStyles.display(
                20,
                color: AppColors.background,
                letterSpacing: 0.15,
              ),
            ),
          const Spacer(),
          _GlobeButton(active: activeTab == ShellTab.explore),
        ],
      ),
    );
  }
}

class _GlobeButton extends StatelessWidget {
  const _GlobeButton({required this.active});

  final bool active;

  static const double _iconPadding = 8;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.background,
      child: InkWell(
        onTap: () => context.go('/explore'),
        child: Container(
          padding: const EdgeInsets.all(_iconPadding),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
            boxShadow: active ? AppDimens.railActiveShadow : null,
          ),
          child: Icon(
            Icons.public,
            size: 24,
            color: active ? AppColors.primaryForeground : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class _RightRail extends ConsumerWidget {
  const _RightRail({required this.activeTab});

  final ShellTab activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailIcon(
          icon: Icons.home,
          selected: activeTab == ShellTab.home,
          onTap: () => context.push(FeedScreen.path),
        ),
        const SizedBox(height: 8),
        _RailIcon(
          icon: Icons.add_box,
          selected: activeTab == ShellTab.add,
          onTap: () => context.push(AddPostScreen.path),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            _RailIcon(
              icon: Icons.notifications_none,
              selected: activeTab == ShellTab.notifications,
              onTap: () => context.push(NotificationsScreen.path),
            ),
            unreadCount.when(
              data: (count) {
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTextStyles.display(
                          count > 99 ? 10 : 12,
                          color: AppColors.primaryForeground,
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const double _squareSize = 60;
  static const double _iconSize = 30;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.secondary,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _squareSize,
          height: _squareSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border,
                width: AppDimens.borderThick,
              ),
              boxShadow: selected ? AppDimens.railActiveShadow : null,
            ),
            child: Center(
              child: Icon(
                icon,
                size: _iconSize,
                color: selected ? AppColors.card : AppColors.background,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
