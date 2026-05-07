import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_text_styles.dart';

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

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.activeTab});

  final ShellTab activeTab;

  static const double _horizontalPadding = 16;
  static const double _verticalPadding = 10;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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

class _RightRail extends StatelessWidget {
  const _RightRail({required this.activeTab});

  final ShellTab activeTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailIcon(
          icon: Icons.home,
          selected: activeTab == ShellTab.home,
          onTap: () => context.go('/feed'),
        ),
        const SizedBox(height: 8),
        _RailIcon(
          icon: Icons.add_box,
          selected: activeTab == ShellTab.add,
          onTap: () => context.go('/add'),
        ),
        const SizedBox(height: 8),
        _RailIcon(
          icon: Icons.notifications_none,
          selected: activeTab == ShellTab.notifications,
          onTap: () => context.go('/notifications'),
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
