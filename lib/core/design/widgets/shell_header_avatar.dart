import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/profile/presentation/profile_providers.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import '../../utils/badge_colors.dart';
import '../app_colors.dart';
import '../app_dimens.dart';
import '../../../features/auth/presentation/auth_notifier.dart';
import 'be_ther_network_image.dart';

class ShellHeaderAvatar extends ConsumerWidget {
  const ShellHeaderAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authNotifierProvider).user;
    final me = ref.watch(profileMeProvider);
    final profile = me.value;
    final avatarUrl =
        profile?['avatarUrl'] as String? ?? authUser?['avatarUrl'] as String? ?? '';
    final badge = profile?['badge'] as String? ?? authUser?['badge'] as String?;

    return InkWell(
      onTap: () => context.push(ProfileScreen.path),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: badgeBorderColor(badge),
            width: AppDimens.borderThick,
          ),
          color: AppColors.muted,
        ),
        clipBehavior: Clip.hardEdge,
        child: avatarUrl.isNotEmpty
            ? BeTherNetworkImage(url: avatarUrl, fit: BoxFit.cover)
            : Icon(Icons.person, color: AppColors.background, size: size * 0.5),
      ),
    );
  }
}
