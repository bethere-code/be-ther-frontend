import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_dimens.dart';
import '../app_text_styles.dart';
import 'loading_label.dart';
import 'pressable.dart';

class BeTherPrimaryButton extends StatelessWidget {
  const BeTherPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  /// Shows animated dots after [loadingLabel] (defaults to [label]).
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading && onPressed != null;
    final radius = BorderRadius.circular(AppDimens.radius);
    final style = AppTextStyles.display(
      22,
      color: AppColors.primaryForeground,
      letterSpacing: 0.1,
    );
    return Pressable(
      onTap: canTap ? onPressed : null,
      enabled: canTap,
      scale: 0.97,
      borderRadius: radius,
      shadowNormal: canTap ? AppDimens.primaryButtonShadow : null,
      shadowPressed: canTap ? AppDimens.primaryButtonShadowPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 32),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.background,
            width: AppDimens.borderThick,
          ),
        ),
        alignment: Alignment.center,
        // Jumping dots > static "..." so busy CTAs don't look frozen.
        child: loading
            ? AuthBusyRow(
                label: loadingLabel ?? label,
                style: style,
              )
            : Text(label, style: style),
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
    final radius = BorderRadius.circular(AppDimens.radius);
    return Pressable(
      onTap: onPressed,
      enabled: enabled,
      scale: 0.97,
      borderRadius: radius,
      shadowNormal: enabled ? AppDimens.primaryButtonShadow : null,
      shadowPressed: enabled ? AppDimens.primaryButtonShadowPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: radius,
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
