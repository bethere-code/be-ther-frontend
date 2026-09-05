import 'dart:io';
import 'dart:ui' as ui;

import 'cover_aspect.dart';

/// Reads pixel size from a local image file and returns snapped cover ratio.
Future<double> measureCoverAspectRatio(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final w = image.width;
  final h = image.height;
  image.dispose();
  if (w < 1 || h < 1) return kCoverAspectLegacy;
  return snapCoverAspectRatio(w / h);
}
