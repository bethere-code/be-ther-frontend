import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography: Bebas Neue (display) + Red Hat Display (body), per Figma Make.
abstract final class AppTextStyles {
  static TextStyle display(double fontSize, {Color? color, double letterSpacing = 0.1}) {
    return GoogleFonts.bebasNeue(
      fontSize: fontSize,
      color: color ?? AppColors.foreground,
      letterSpacing: letterSpacing * fontSize,
      height: 1,
    );
  }

  static TextStyle body(
    double fontSize, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double height = 1.4,
  }) {
    return GoogleFonts.redHatDisplay(
      fontSize: fontSize,
      color: color ?? AppColors.foreground,
      fontWeight: weight,
      height: height,
    );
  }
}
