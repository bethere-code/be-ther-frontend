import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import 'author_avatar.dart';

/// Sheet header for others' events — replaces "EVENT DETAILS" with avatar + @username.
class EventSheetCreatorHeader extends StatelessWidget {
  const EventSheetCreatorHeader({
    super.key,
    required this.avatarUrl,
    required this.username,
    this.badge,
    required this.onTap,
  });

  final String avatarUrl;
  final String username;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final handle = username.trim();
    if (handle.isEmpty) {
      return Text(
        'EVENT DETAILS',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.display(
          20,
          color: AppColors.primary,
          letterSpacing: 0.05,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AuthorAvatar(
              avatarUrl: avatarUrl,
              username: handle,
              badge: badge,
              size: 36,
              interactive: false,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '@$handle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(
                  20,
                  color: AppColors.primary,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
