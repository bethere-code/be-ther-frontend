import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/loading_label.dart';

/// "Continue with Apple" under the Google button. iOS only — Android keeps
/// Google + email OTP.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final labelStyle = AppTextStyles.body(
      13,
      color: AppColors.foreground,
      weight: FontWeight.w700,
    );
    const logo = Icon(Icons.apple, size: 20, color: Colors.black);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: 230,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.card,
              side: BorderSide(color: AppColors.border, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onPressed,
            child: busy
                ? AuthBusyRow(
                    label: 'CONNECTING',
                    leading: logo,
                    style: labelStyle,
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(width: 10),
                      Text('Continue with Apple', style: labelStyle),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
