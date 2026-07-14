import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public web origin used in shared event links (no trailing slash).
String shareWebBaseUrl() {
  final fromEnv = dotenv.maybeGet('SHARE_BASE_URL')?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv.replaceAll(RegExp(r'/+$'), '');
  }

  final api = dotenv.maybeGet('API_BASE_URL')?.trim() ?? '';
  if (api.isEmpty) return 'https://be-ther.com';

  final uri = Uri.tryParse(api);
  if (uri == null || uri.host.isEmpty) return 'https://be-ther.com';

  return '${uri.scheme}://${uri.host}';
}

String buildEventShareUrl(String postId) {
  final id = postId.trim();
  return '${shareWebBaseUrl()}/e/$id';
}

String buildShareDescription({
  required String location,
  String? caption,
  String? venue,
  String? date,
}) {
  final text = caption?.trim();
  if (text != null && text.isNotEmpty) {
    return text.length > 200 ? '${text.substring(0, 197)}...' : text;
  }

  final meta = [venue?.trim(), date?.trim()].whereType<String>().where((v) => v.isNotEmpty);
  if (meta.isNotEmpty) return meta.join(' · ');

  return 'Discover $location on Be Ther';
}
