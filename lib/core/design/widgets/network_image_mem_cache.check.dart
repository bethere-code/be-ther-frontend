import 'network_image_mem_cache.dart';

void main() {
  assert(networkImageMemCachePx(40, 2) == 80);
  assert(networkImageMemCachePx(400, 3) == 1200);
  assert(networkImageMemCachePx(2000, 3) == 2048);
  assert(networkImageMemCachePx(0, 2) == 1);

  // Wide feed slot (21:9) → budget width
  assert(
    networkImageMemCacheWidthForBox(
          layoutWidth: 390,
          layoutHeight: 390 * 9 / 21,
          devicePixelRatio: 2,
        ) ==
        780,
  );
  // Taller slot (3:2 portrait-ish box) → budget the longer edge (height)
  assert(
    networkImageMemCacheWidthForBox(
          layoutWidth: 200,
          layoutHeight: 300,
          devicePixelRatio: 2,
        ) ==
        600,
  );
  // 16:9 vs 4:3 boxes still one-axis; no second dim that could warp decode
  assert(
    networkImageMemCacheWidthForBox(
          layoutWidth: 360,
          layoutHeight: 360 * 9 / 16,
          devicePixelRatio: 3,
        ) ==
        1080,
  );

  // ignore: avoid_print
  print('network_image_mem_cache.check: ok');
}
