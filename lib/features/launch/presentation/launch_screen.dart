import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/design/widgets/be_ther_buttons.dart';
import '../../auth/presentation/auth_email_screen.dart';
import '../../auth/presentation/auth_signup_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  static const path = '/';
  static const name = 'launch';

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.secondary,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BE THER',
                    style: AppTextStyles.display(
                      56,
                      color: AppColors.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'follow what you love',
                    style: AppTextStyles.body(18, color: AppColors.background, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 48),
                  BeTherPrimaryButton(
                    label: 'SIGN UP',
                    onPressed: () => context.push(AuthSignupScreen.path),
                  ),
                  const SizedBox(height: 16),
                  BeTherSecondaryButton(
                    label: 'LOG IN',
                    onPressed: () => context.push(AuthEmailScreen.path),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'By continuing, you agree to our Terms & Privacy',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(13, color: AppColors.background.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
