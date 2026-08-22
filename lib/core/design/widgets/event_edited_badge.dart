import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_text_styles.dart';

/// Small label shown beside event time after the author edits the post.
class EventEditedBadge extends StatelessWidget {
  const EventEditedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.65),
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderThin,
        ),
      ),
      child: Text(
        'EDITED',
        style: AppTextStyles.body(
          9,
          weight: FontWeight.w800,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}
