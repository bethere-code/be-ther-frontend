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
        color: AppColors.secondaryForeground,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.secondaryForeground,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.more_vert, color: AppColors.secondary, size: 22),
    );
  }
}
