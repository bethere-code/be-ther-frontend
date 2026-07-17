import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a ticket-link preview image into a local temp file.
///
/// [imageUrl] must already be resolved (usually via `/api/v1/link-preview`).
/// Scraping HTML on the phone often fails — Cloudflare blocks in-app clients —
/// while WhatsApp scrapes from Meta's servers. We do the same via our API.
Future<String?> downloadPreviewImageToTemp(String imageUrl) async {
  final absolute = imageUrl.trim();
  if (absolute.isEmpty) return null;

  final uri = Uri.tryParse(absolute);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }

  final dir = await getTemporaryDirectory();
  final ext = _guessImageExtension(absolute);
  final savePath =
      '${dir.path}/ticket_preview_${DateTime.now().millisecondsSinceEpoch}$ext';

  await Dio().download(
    absolute,
    savePath,
    options: Options(
      responseType: ResponseType.bytes,
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'image/*,*/*;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
      validateStatus: (status) => status != null && status >= 200 && status < 400,
    ),
  );

  final file = File(savePath);
  if (!await file.exists() || await file.length() < 32) return null;
  return savePath;
}

String _guessImageExtension(String imageUrl) {
  final path = Uri.tryParse(imageUrl)?.path.toLowerCase() ?? '';
  if (path.endsWith('.png')) return '.png';
  if (path.endsWith('.webp')) return '.webp';
  if (path.endsWith('.gif')) return '.gif';
  return '.jpg';
}
