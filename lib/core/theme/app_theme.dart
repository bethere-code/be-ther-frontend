import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_dimens.dart';
import '../design/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.background,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: AppDimens.borderThick),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.ring, width: AppDimens.borderThick),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: AppTextStyles.body(16, color: AppColors.mutedForeground),
      ),
      textTheme: TextTheme(
        bodyLarge: AppTextStyles.body(16),
        bodyMedium: AppTextStyles.body(14),
        titleMedium: AppTextStyles.body(16, weight: FontWeight.w700),
      ),
    );
  }
}
