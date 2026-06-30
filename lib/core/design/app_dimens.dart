import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Layout and “chunky border” sizing from Figma Make screens.
abstract final class AppDimens {
  static const double borderThinnest = 1;
  static const double borderThin = 2;
  static const double border = 3;
  static const double borderThick = 4;

  /// Right rail footprint: 60px control + 8px padding on each side.
  static const double railWidth = 76;

  /// Primary CTA shadow: `0 6px 0` cream block.
  static const List<BoxShadow> primaryButtonShadow = [
    BoxShadow(color: AppColors.background, offset: Offset(0, 6), blurRadius: 0),
  ];

  static const List<BoxShadow> railActiveShadow = [
    BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
  ];
}
