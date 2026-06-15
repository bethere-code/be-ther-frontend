import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> pickPhoto(
  BuildContext context, {
  required ImageSource source,
  bool square = false,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 100,
  );
  if (picked == null) return null;

  if (!context.mounted) return picked.path;
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return picked.path;
  }

  try {
    final CroppedFile? cropped;
    if (square) {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 100,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop Photo', lockAspectRatio: true),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
    } else {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop Photo', lockAspectRatio: false),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
    }
    return cropped?.path ?? picked.path;
  } catch (_) {
    return picked.path;
  }
}

Future<File> compressPhoto(String path) async {
  final size = await File(path).length();
  final target = (size * 0.6).round();

  List<int>? bytes;
  for (var q = 90; q >= 40; q -= 5) {
    final out = await FlutterImageCompress.compressWithFile(
      path,
      quality: q,
      format: CompressFormat.jpeg,
    );
    if (out == null) continue;
    bytes = out;
    if (out.length <= target) break;
  }

  if (bytes == null) {
    throw Exception('Could not compress image.');
  }

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(bytes);
  return file;
}
