/// Decode budget for network images (layout size × device pixel ratio).
///
/// Industry rule (Flutter / Instagram-style feeds):
/// - Pass **only one** of [memCacheWidth] / [memCacheHeight].
/// - Setting **both** forces a fixed decode box and warps any source ratio
///   (3:2, 4:3, 16:9, 21:9, …); [BoxFit] cannot undo that.
/// - For full-bleed / cover slots, budget the **longer** layout edge so cover
///   stays sharp regardless of the photo’s aspect ratio.
int networkImageMemCachePx(
  double logicalPx,
  double devicePixelRatio, {
  int max = 2048,
}) {
  if (!(logicalPx > 0) || !(devicePixelRatio > 0)) return 1;
  final v = (logicalPx * devicePixelRatio).round();
  if (v < 1) return 1;
  if (v > max) return max;
  return v;
}

/// One-axis decode size for a laid-out box. Always use as [memCacheWidth] only
/// (leave height null) so the bitmap keeps the file’s real aspect ratio.
int networkImageMemCacheWidthForBox({
  required double layoutWidth,
  required double layoutHeight,
  required double devicePixelRatio,
  double fallbackWidth = 0,
}) {
  final w = layoutWidth.isFinite && layoutWidth > 0 ? layoutWidth : 0.0;
  final h = layoutHeight.isFinite && layoutHeight > 0 ? layoutHeight : 0.0;
  final edge = w >= h && w > 0
      ? w
      : h > 0
          ? h
          : (fallbackWidth > 0 ? fallbackWidth : 1.0);
  return networkImageMemCachePx(edge, devicePixelRatio);
}
