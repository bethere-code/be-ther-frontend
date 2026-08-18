import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_text_styles.dart';
import 'pressable.dart';

class BeTherPrimaryButton extends StatelessWidget {
  const BeTherPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      enabled: enabled,
      scale: 0.97,
      shadowNormal: enabled ? AppDimens.primaryButtonShadow : null,
      shadowPressed: enabled ? AppDimens.primaryButtonShadowPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 32),
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(
            color: AppColors.background,
            width: AppDimens.borderThick,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.display(
            22,
            color: AppColors.primaryForeground,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class BeTherSecondaryButton extends StatelessWidget {
  const BeTherSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      enabled: enabled,
      scale: 0.97,
      shadowNormal: enabled ? AppDimens.primaryButtonShadow : null,
      shadowPressed: enabled ? AppDimens.primaryButtonShadowPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: AppColors.background,
            width: AppDimens.borderThick,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.display(
            24,
            color: AppColors.secondary,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
