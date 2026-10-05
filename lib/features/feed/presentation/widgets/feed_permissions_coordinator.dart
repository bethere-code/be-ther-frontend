import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../profile/data/user_repository.dart';

/// Requests notification then location when the user opens the feed.
class FeedPermissionsCoordinator {
  FeedPermissionsCoordinator._();

  static bool _inFlight = false;

  /// Soft-deny / permanent-deny: show settings sheet at most once per cold start
  /// so we don't spam every feed revisit after "Not now".
  static final Set<Permission> _settingsPromptedThisSession = {};

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Notification first, then location.
  static Future<void> ensure(
    BuildContext context, {
    UserRepository? userRepository,
  }) async {
    if (!_supported || _inFlight) return;

    _inFlight = true;
    try {
      await _ensure(
        context,
        permission: Permission.notification,
        title: 'ENABLE NOTIFICATIONS',
        body:
            'Turn on notifications so you do not miss event updates, messages, '
            'and activity from people you follow.',
      );
      if (!context.mounted) return;
      await _ensure(
        context,
        permission: Permission.locationWhenInUse,
        title: 'ENABLE LOCATION',
        body:
            'Allow location access to discover events and places near you and '
            'keep your feed relevant to where you are.',
      );
      await syncToProfile(userRepository);
    } finally {
      _inFlight = false;
    }
  }

  /// Reads current OS permission state and saves it on the user profile.
  static Future<void> syncToProfile(UserRepository? userRepository) async {
    if (!_supported || userRepository == null) return;
    try {
      final notification = await Permission.notification.status;
      final location = await Permission.locationWhenInUse.status;
      await userRepository.syncDevicePermissions(
        notification: statusToApi(notification),
        location: statusToApi(location),
      );
    } catch (_) {
      // Stats sync must not block the feed.
    }
  }

  static String statusToApi(PermissionStatus status) {
    if (status.isGranted) return 'granted';
    if (status.isLimited) return 'limited';
    if (status.isProvisional) return 'provisional';
    if (status.isPermanentlyDenied) return 'permanently_denied';
    if (status.isRestricted) return 'restricted';
    if (status.isDenied) return 'denied';
    return 'unknown';
  }

  static Future<void> _ensure(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String body,
  }) async {
    var status = await permission.status;
    if (_isSatisfied(status)) return;

    // Still eligible for the OS sheet (first ask / soft deny) — try it.
    // After a soft deny, Android often returns denied with no UI; we must
    // still fall through to our settings prompt below.
    if (!_needsSettings(status)) {
      status = await permission.request();
      if (_isSatisfied(status)) return;
    }

    if (!context.mounted) return;
    await _showOpenSettingsDialog(
      context,
      permission: permission,
      title: title,
      body: body,
    );
  }

  static bool _isSatisfied(PermissionStatus status) =>
      status.isGranted || status.isLimited || status.isProvisional;

  static bool _needsSettings(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  static Future<void> _showOpenSettingsDialog(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String body,
  }) async {
    if (_settingsPromptedThisSession.contains(permission)) return;
    _settingsPromptedThisSession.add(permission);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final r = BorderRadius.circular(AppDimens.feedCardRadius);
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: r,
            side: const BorderSide(
              color: AppColors.cardBorder,
              width: AppDimens.borderThin,
            ),
          ),
          title: Text(
            title,
            style: AppTextStyles.display(22, color: AppColors.secondary),
          ),
          content: Text(
            body,
            style: AppTextStyles.body(14, color: AppColors.mutedForeground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'NOT NOW',
                style: AppTextStyles.body(14, weight: FontWeight.w700),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
                shape: RoundedRectangleBorder(borderRadius: r),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              child: Text(
                'GO TO SETTINGS',
                style: AppTextStyles.display(
                  15,
                  color: AppColors.primaryForeground,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
