import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  required String location,
  String? ticketUrl,
  String? caption,
}) async {
  final buffer = StringBuffer('Check out $location on Be Ther');
  if (caption != null && caption.trim().isNotEmpty) {
    buffer.write('\n\n$caption');
  }
  final ticket = ticketUrl?.trim() ?? '';
  if (ticket.isNotEmpty) {
    buffer.write('\n\nTickets: $ticket');
  }
  await Share.share(buffer.toString());
}
