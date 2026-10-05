import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'network_image_mem_cache.dart';

export 'network_image_mem_cache.dart';

/// App-wide network image. Fixed-size slots must wrap this in [AspectRatio]
/// (feed already does) so placeholder → bitmap never changes layout height.
///
/// Zero fade: CachedNetworkImage’s default 500ms/120ms fade runs an opacity
/// animation on the UI thread when each cover resolves — that is the “jerk
/// while the image loads” on Android feeds. Calendar feels smooth because it
/// has no network decode + fade.
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
    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final screenW = MediaQuery.sizeOf(context).width;
        // One axis only — works for every upload crop (3:2, 4:3, 16:9, …).
        final memW = networkImageMemCacheWidthForBox(
          layoutWidth: constraints.maxWidth,
          layoutHeight: constraints.maxHeight,
          devicePixelRatio: dpr,
          fallbackWidth: screenW,
        );

        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: memW,
          filterQuality: FilterQuality.low,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          placeholder: (context, url) =>
              const ColoredBox(color: AppColors.muted),
          errorWidget: (context, url, error) => const ColoredBox(
            color: AppColors.muted,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.mutedForeground,
                size: 18,
              ),
            ),
          ),
        );
      },
    );

    if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    }
    return image;
  }
}
