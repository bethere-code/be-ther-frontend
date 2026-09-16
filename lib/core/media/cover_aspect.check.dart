import 'cover_aspect.dart';

void main() {
  assert((snapCoverAspectRatio(1.52) - kCoverAspect3x2).abs() < 0.001);
  assert((snapCoverAspectRatio(1.78) - kCoverAspect16x9).abs() < 0.001);
  assert((snapCoverAspectRatio(1.35) - kCoverAspect4x3).abs() < 0.001);
  assert(kCoverAspectDefault == kCoverAspect16x9);
  assert(
    resolveCoverAspectRatio(stored: null, usesDefaultCover: true) ==
        kCoverAspectDefault,
  );
  // Older taller default uploads still display as 16:9.
  assert(
    resolveCoverAspectRatio(stored: 0.75, usesDefaultCover: true) ==
        kCoverAspect16x9,
  );
  assert(
    resolveCoverAspectRatio(stored: 1.5, usesDefaultCover: true) ==
        kCoverAspect16x9,
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
