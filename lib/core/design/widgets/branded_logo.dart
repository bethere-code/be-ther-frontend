import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_images.dart';

class BrandedLogo extends StatelessWidget {
  final double logoHeight;
  final double sparkleSize;
  final double spacing;

  const BrandedLogo({
    super.key,
    this.logoHeight = 80,
    this.sparkleSize = 32,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome,
          size: sparkleSize,
          color: AppColors.primary,
        ),
        SizedBox(width: spacing),
        Image.asset(
          AppImages.beatherLogo,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
        SizedBox(width: spacing),
        Icon(
          Icons.auto_awesome,
          size: sparkleSize,
          color: AppColors.primary,
        ),
      ],
    );
  }
}
