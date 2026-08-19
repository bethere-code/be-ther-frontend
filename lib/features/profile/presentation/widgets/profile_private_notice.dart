import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/profile_user.dart';

bool isPrivateProfileLocked(ProfileUser user) {
  return !user.isOwnProfile &&
      user.settings.isPrivateProfile &&
      !user.isFollowing;
}

bool isPrivateProfileError(Object error) {
  if (error is ApiException && error.statusCode == 403) return true;
  return error.toString().toLowerCase().contains('private profile');
}

class ProfilePrivateNotice extends StatelessWidget {
  const ProfilePrivateNotice({
    super.key,
    this.detail = 'Follow to see their calendar and events.',
  });

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(
              'This profile is private',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(20, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(15, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
