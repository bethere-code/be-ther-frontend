import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../add_post_screen.dart';

/// One-shot welcome after signup (or Google from the signup screen).
Future<void> showWelcomeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: AppColors.secondary.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.border,
            width: AppDimens.border,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to BeTher,\nyour social calendar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  32,
                  color: AppColors.secondary,
                  letterSpacing: 0.02,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first event and share what you\'re going to.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  15,
                  color: AppColors.mutedForeground,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mutedForeground,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'MAYBE LATER',
                        style: AppTextStyles.display(
                          13,
                          color: AppColors.mutedForeground,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                        if (context.mounted) context.go(AddPostScreen.path);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: AppColors.border,
                            width: AppDimens.border,
                          ),
                        ),
                      ),
                      child: Text(
                        'CREATE EVENT',
                        style: AppTextStyles.display(
                          13,
                          color: AppColors.primaryForeground,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
