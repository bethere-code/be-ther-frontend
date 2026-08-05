import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../design/app_colors.dart';
import '../design/app_images.dart';

/// Renders the BeTher logo on a brand background and writes a temp PNG
/// suitable for upload when the user skips an event photo.
///
/// Portrait (3:4) so explore/search masonry cards stay tall enough
/// and don’t leave awkward gaps next to taller event photos.
Future<File> buildDefaultEventCoverFile() async {
  const width = 1080;
  const height = 1440; // 3:4 portrait

  final logoData = await rootBundle.load(AppImages.beatherLogo);
  final codec = await ui.instantiateImageCodec(
    logoData.buffer.asUint8List(),
  );
  final frame = await codec.getNextFrame();
  final logo = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());
  final rect = Offset.zero & size;

  // Neat navy → soft coral wash (brand, not flat black).
  final bg = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      const [
        Color(0xFF1A2332),
        Color(0xFF243044),
        Color(0xFF3D2A28),
      ],
      const [0.0, 0.55, 1.0],
    );
  canvas.drawRect(rect, bg);

  // Soft primary glow behind the logo.
  final glow = Paint()
    ..shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.48),
      size.width * 0.55,
      [
        AppColors.primary.withValues(alpha: 0.28),
        AppColors.primary.withValues(alpha: 0.0),
      ],
    );
  canvas.drawRect(rect, glow);

  // Thin cream frame so the cover feels intentional.
  final framePaint = Paint()
    ..color = AppColors.background.withValues(alpha: 0.22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 12;
  canvas.drawRect(rect.deflate(22), framePaint);

  final maxLogoW = size.width * 0.62;
  final scale = maxLogoW / logo.width;
  final logoW = logo.width * scale;
  final logoH = logo.height * scale;
  final dst = Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: logoW,
    height: logoH,
  );
  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );

  logo.dispose();

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  if (bytes == null) {
    throw Exception('Could not create default event photo');
  }

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/be_ther_default_event_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file;
}
