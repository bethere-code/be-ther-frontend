import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';

/// Requests notification then location when the user opens the feed.
class FeedPermissionsCoordinator {
  FeedPermissionsCoordinator._();

  static bool _inFlight = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Notification first, then location. Runs on every feed visit while not granted.
  static Future<void> ensure(BuildContext context) async {
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
    } finally {
      _inFlight = false;
    }
  }

  static Future<void> _ensure(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String body,
  }) async {
    var status = await permission.status;

    if (_isSatisfied(status)) return;

    if (_needsSettings(status)) {
      if (!context.mounted) return;
      await _showOpenSettingsDialog(
        context,
        title: title,
        body: body,
      );
      return;
    }

    status = await permission.request();
    if (_isSatisfied(status)) return;

    if (_needsSettings(status)) {
      if (!context.mounted) return;
      await _showOpenSettingsDialog(
        context,
        title: title,
        body: body,
      );
    }
  }

  static bool _isSatisfied(PermissionStatus status) =>
      status.isGranted || status.isLimited || status.isProvisional;

  static bool _needsSettings(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  static Future<void> _showOpenSettingsDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(title, style: AppTextStyles.display(22, color: AppColors.secondary)),
        content: Text(body, style: AppTextStyles.body(14, color: AppColors.mutedForeground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: AppTextStyles.body(14, weight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: Text(
              'GO TO SETTINGS',
              style: AppTextStyles.display(14, color: AppColors.primaryForeground),
            ),
          ),
        ],
      ),
    );
  }
}
