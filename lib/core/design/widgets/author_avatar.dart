import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/profile/presentation/profile_screen.dart';
import '../../utils/badge_colors.dart';
import '../app_dimens.dart';
import '../app_colors.dart';
import 'be_ther_network_image.dart';

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.avatarUrl,
    required this.username,
    this.badge,
    this.size = 40,
    this.onTap,
  });

  final String avatarUrl;
  final String username;
  final String? badge;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = badgeBorderColor(badge);
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppDimens.borderThick,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: avatarUrl.isNotEmpty
          ? BeTherNetworkImage(url: avatarUrl, fit: BoxFit.cover)
          : Icon(Icons.person, color: AppColors.foreground, size: size * 0.55),
    );

    if (onTap == null && username.isEmpty) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            (username.isEmpty
                ? null
                : () => context.push(ProfileScreen.pathForUser(username))),
        child: child,
      ),
    );
  }
}
