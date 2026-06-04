import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/link_utils.dart';

Future<void> showExploreEventSheet({
  required BuildContext context,
  required Map<String, dynamic> event,
  required bool bookmarked,
  required Future<bool> Function() onToggleBookmark,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ExploreEventSheet(
      event: event,
      initialBookmarked: bookmarked,
      onToggleBookmark: onToggleBookmark,
    ),
  );
}

class _ExploreEventSheet extends StatefulWidget {
  const _ExploreEventSheet({
    required this.event,
    required this.initialBookmarked,
    required this.onToggleBookmark,
  });

  final Map<String, dynamic> event;
  final bool initialBookmarked;
  final Future<bool> Function() onToggleBookmark;

  @override
  State<_ExploreEventSheet> createState() => _ExploreEventSheetState();
}

class _ExploreEventSheetState extends State<_ExploreEventSheet> {
  late bool _bookmarked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.initialBookmarked;
  }

  Future<void> _toggleBookmark() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await widget.onToggleBookmark();
      if (mounted) setState(() => _bookmarked = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update wishlist')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? '';
    final location = widget.event['location'] as String? ?? '';
    final date = widget.event['date'] as String? ?? '';
    final venue = widget.event['venue'] as String? ?? '';
    final image = widget.event['image'] as String? ?? widget.event['imageUrl'] as String? ?? '';
    final status = widget.event['status'] as String? ?? '';
    final attendees = widget.event['attendees'] as int? ?? 0;
    final trending = widget.event['trending'] as bool? ?? false;
    final ticketUrl = widget.event['ticketUrl'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              if (image.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: BeTherNetworkImage(url: image, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              if (trending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: AppColors.accent,
                  child: Text(
                    'HOT',
                    style: AppTextStyles.display(10, color: AppColors.accentForeground),
                  ),
                ),
              if (trending) const SizedBox(height: 8),
              Text(
                title,
                style: AppTextStyles.display(24, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(location, style: AppTextStyles.body(14, weight: FontWeight.w700)),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  status == 'been' ? 'BEEN' : status == 'going' ? 'GOING' : 'INTERESTED',
                  style: AppTextStyles.display(12, color: AppColors.primary),
                ),
              ],
              if (date.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('DATE\n$date', style: AppTextStyles.body(14, weight: FontWeight.w700)),
              ],
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('VENUE\n$venue', style: AppTextStyles.body(14, weight: FontWeight.w700)),
              ],
              const SizedBox(height: 8),
              Text(
                '$attendees likes',
                style: AppTextStyles.body(13, color: AppColors.mutedForeground, weight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _toggleBookmark,
                      child: Text(_bookmarked ? 'SAVED' : 'SAVE TO WISHLIST'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => sharePostContent(
                      location: title.isNotEmpty ? title : location,
                      ticketUrl: ticketUrl,
                    ),
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
              if (ticketUrl != null && ticketUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => openExternalUrl(context, ticketUrl),
                    child: Text(
                      'GET TICKETS',
                      style: AppTextStyles.display(14, color: AppColors.primaryForeground),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
