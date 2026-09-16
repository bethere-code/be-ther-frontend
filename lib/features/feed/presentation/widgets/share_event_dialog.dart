import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_images.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/utils/link_utils.dart';
import 'package:be_ther/core/ui/app_toast.dart';

/// Shown after creating an event — nudge to share the public link.
Future<void> showShareEventDialog(
  BuildContext context, {
  required String postId,
  required String location,
  String? caption,
  String? venue,
  String? date,
  String? ticketUrl,
  String? imageUrl,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: AppColors.secondary.withValues(alpha: 0.55),
    builder: (dialogContext) {
      var sharing = false;
      return StatefulBuilder(
        builder: (context, setLocal) {
          return Dialog(
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radius),
              side: const BorderSide(
                color: AppColors.border,
                width: AppDimens.border,
              ),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Use BeTher to its full potential',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(
                      28,
                      color: AppColors.secondary,
                      letterSpacing: 0.02,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    AppImages.shareEventPrompt,
                    height: 148,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share this event with your friends and make it more engaging.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      15,
                      color: AppColors.mutedForeground,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: sharing
                          ? null
                          : () async {
                              setLocal(() => sharing = true);
                              try {
                                await sharePostContent(
                                  postId: postId,
                                  location: location,
                                  caption: caption,
                                  venue: venue,
                                  date: date,
                                  ticketUrl: ticketUrl,
                                  imageUrl: imageUrl,
                                );
                                if (dialogContext.mounted) {
                                  Navigator.of(
                                    dialogContext,
                                    rootNavigator: true,
                                  ).pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.show(
                                    context,
                                    e
                                        .toString()
                                        .replaceFirst('Exception: ', ''),
                                  );
                                }
                                setLocal(() => sharing = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.7,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radius),
                          side: const BorderSide(
                            color: AppColors.border,
                            width: AppDimens.border,
                          ),
                        ),
                      ),
                      child: Text(
                        sharing ? 'SHARING…' : 'SHARE EVENT',
                        style: AppTextStyles.display(
                          15,
                          color: AppColors.primaryForeground,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
