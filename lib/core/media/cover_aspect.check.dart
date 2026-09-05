import 'cover_aspect.dart';

void main() {
  assert((snapCoverAspectRatio(1.52) - kCoverAspect3x2).abs() < 0.001);
  assert((snapCoverAspectRatio(1.78) - kCoverAspect16x9).abs() < 0.001);
  assert((snapCoverAspectRatio(0.76) - kCoverAspectDefault).abs() < 0.001);
  assert(
    resolveCoverAspectRatio(stored: null, usesDefaultCover: true) ==
        kCoverAspectDefault,
  );
  assert(
    resolveCoverAspectRatio(stored: null, usesDefaultCover: false) ==
        kCoverAspectLegacy,
  );
  assert(resolveCoverAspectRatio(stored: 1.5) == 1.5);
  assert(parseCoverAspectRatio(1.5) == 1.5);
  assert(parseCoverAspectRatio(null) == null);
  // ignore: avoid_print
  print('cover_aspect.check: ok');
}
