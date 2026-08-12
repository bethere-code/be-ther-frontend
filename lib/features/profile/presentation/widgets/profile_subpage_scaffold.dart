import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';

/// Navy header + cream body used by profile Events / Followers / Following.
class ProfileSubpageScaffold extends StatelessWidget {
  const ProfileSubpageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.display(
                22,
                color: AppColors.primary,
                letterSpacing: 0.08,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTextStyles.body(
                  12,
                  color: AppColors.background.withValues(alpha: 0.75),
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(AppDimens.borderThick),
          child: ColoredBox(
            color: AppColors.border,
            child: SizedBox(height: AppDimens.borderThick, width: double.infinity),
          ),
        ),
      ),
      body: child,
    );
  }
}
