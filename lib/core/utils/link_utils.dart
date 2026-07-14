import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/share_config.dart';

Future<void> openExternalUrl(BuildContext context, String? rawUrl) async {
  final url = rawUrl?.trim() ?? '';
  if (url.isEmpty) return;

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid link')),
    );
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open link')),
    );
  }
}

Future<void> sharePostContent({
  required String postId,
  required String location,
  String? imageUrl,
  String? ticketUrl,
  String? caption,
  String? venue,
  String? date,
}) async {
  final id = postId.trim();
  if (id.isEmpty) {
    throw Exception('Cannot share this event yet');
  }

  final title = location.trim().isNotEmpty ? location.trim() : 'Be Ther Event';
  final description = buildShareDescription(
    location: title,
    caption: caption,
    venue: venue,
    date: date,
  );
  final shareUrl = buildEventShareUrl(id);

  final buffer = StringBuffer('Check out $title on Be Ther');
  buffer.write('\n\n$description');
  buffer.write('\n\n$shareUrl');

  final ticket = ticketUrl?.trim() ?? '';
  if (ticket.isNotEmpty) {
    buffer.write('\n\nTickets: $ticket');
  }

  await Share.share(
    buffer.toString(),
    subject: title,
  );
}
