import 'package:flutter/material.dart';

import '../design/app_colors.dart';

Color badgeBorderColor(String? badge) {
  switch (badge) {
    case 'blue':
      return const Color(0xFF3B82F6);
    case 'silver':
      return const Color(0xFF94A3B8);
    case 'gold':
      return AppColors.accent;
    default:
      return AppColors.border;
  }
}
