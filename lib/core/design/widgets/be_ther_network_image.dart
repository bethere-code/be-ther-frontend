import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';

class BeTherNetworkImage extends StatelessWidget {
  const BeTherNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.aspectRatio,
  });

  final String url;
  final BoxFit fit;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => ColoredBox(
        color: AppColors.muted,
        child: Center(
          child: Icon(Icons.image_outlined, color: AppColors.mutedForeground, size: 40),
        ),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: AppColors.muted,
        child: Icon(Icons.broken_image_outlined, color: AppColors.mutedForeground, size: 40),
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: image);
    }
    return image;
  }
}
