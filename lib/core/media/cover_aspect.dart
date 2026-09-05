/// Allowed cover width÷height values (matches crop presets + default cover).
const kCoverAspect3x2 = 3 / 2;
const kCoverAspect16x9 = 16 / 9;
const kCoverAspect4x3 = 4 / 3;
/// Default event cover from [buildDefaultEventCoverFile] is 1080×1440.
const kCoverAspectDefault = 3 / 4;
/// Legacy posts with no stored ratio (landscape-ish).
const kCoverAspectLegacy = 16 / 9;

const kCoverAspectPresets = <double>[
  kCoverAspect3x2,
  kCoverAspect16x9,
  kCoverAspect4x3,
  kCoverAspectDefault,
];

/// Snap a measured ratio to the nearest allowed preset.
double snapCoverAspectRatio(double raw) {
  var best = kCoverAspectPresets.first;
  var bestDist = (raw - best).abs();
  for (var i = 1; i < kCoverAspectPresets.length; i++) {
    final p = kCoverAspectPresets[i];
    final d = (raw - p).abs();
    if (d < bestDist) {
      best = p;
      bestDist = d;
    }
  }
  return best;
}

/// Slot ratio for feed / sheets. Prefer stored value; else default-cover or legacy.
double resolveCoverAspectRatio({
  double? stored,
  bool usesDefaultCover = false,
}) {
  if (stored != null && stored >= 0.4 && stored <= 3.5) {
    return stored;
  }
  if (usesDefaultCover) return kCoverAspectDefault;
  return kCoverAspectLegacy;
}

double? parseCoverAspectRatio(dynamic raw) {
  if (raw is num) {
    final v = raw.toDouble();
    if (v >= 0.4 && v <= 3.5) return v;
  }
  if (raw is String) {
    final v = double.tryParse(raw);
    if (v != null && v >= 0.4 && v <= 3.5) return v;
  }
  return null;
}
