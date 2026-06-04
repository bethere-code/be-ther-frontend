import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Circular ⋮ icon used as [PopupMenuButton] child on feed and profile.
class PostMoreMenuIcon extends StatelessWidget {
  const PostMoreMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.more_vert,
        color: AppColors.secondaryForeground,
        size: 22,
      ),
    );
  }
}
