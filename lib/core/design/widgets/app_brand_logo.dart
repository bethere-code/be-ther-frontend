import 'package:flutter/material.dart';

import '../app_images.dart';

/// Single chrome logo for app headers + bottom bar — same size / left edge everywhere.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.onTap,
    this.height = AppBrandLogo.chromeHeight,
  });

  /// Header / bottom-bar mark size (slightly up from the old width:60 look).
  static const double chromeHeight = 48;

  /// Fixed leading slot so Explore / Alerts titles stay optically centered.
  static const double slotWidth = 72;

  /// Shared header inset (logo side + trailing controls).
  static const double headerInset = 12;

  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: slotWidth,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          AppImages.beatherLogo,
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (onTap == null) return image;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: image,
      ),
    );
  }
}
