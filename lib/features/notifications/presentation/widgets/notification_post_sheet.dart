import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../profile/presentation/profile_screen.dart';

Future<void> showNotificationPostSheet({
  required BuildContext context,
  required Map<String, dynamic> post,
  required String actorUsername,
}) {
  final location = post['location'] as String? ?? '';
  final imageUrl = post['imageUrl'] as String? ?? '';
  final caption = post['caption'] as String? ?? '';
  final status = post['status'] as String? ?? 'going';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PopScope(
      canPop: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: BeTherNetworkImage(url: imageUrl, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            Text(location, style: AppTextStyles.display(20, color: AppColors.secondary)),
            const SizedBox(height: 8),
            Text(
              status.toUpperCase(),
              style: AppTextStyles.body(13, weight: FontWeight.w800),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(caption, style: AppTextStyles.body(14)),
            ],
            const SizedBox(height: 16),
            if (actorUsername.isNotEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(ProfileScreen.pathForUser(actorUsername));
                },
                child: const Text('VIEW PROFILE'),
              ),
          ],
        ),
      ),
    ),
  );
}
