import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';
import '../../../../core/utils/event_date_utils.dart';
import '../../../../core/utils/link_utils.dart';
import '../../../feed/presentation/feed_providers.dart';

Future<void> showExploreEventSheet({
  required BuildContext context,
  required Map<String, dynamic> event,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PopScope(
      canPop: true,
      child: _ExploreEventSheet(event: event),
    ),
  );
}

class _ExploreEventSheet extends ConsumerStatefulWidget {
  const _ExploreEventSheet({required this.event});

  final Map<String, dynamic> event;

  @override
  ConsumerState<_ExploreEventSheet> createState() => _ExploreEventSheetState();
}

class _ExploreEventSheetState extends ConsumerState<_ExploreEventSheet> {
  late bool _inCalendar;
  bool _calendarBusy = false;

  @override
  void initState() {
    super.initState();
    _inCalendar = widget.event['inCalendar'] as bool? ?? false;
  }

  String get _postId =>
      widget.event['postId']?.toString() ?? widget.event['_id']?.toString() ?? '';

  Future<void> _toggleCalendar() async {
    if (_postId.isEmpty || _calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final next = await ref.read(postsRepositoryProvider).toggleCalendar(_postId);
      if (mounted) setState(() => _inCalendar = next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? '';
    final location = widget.event['location'] as String? ?? '';
    final country = widget.event['country'] as String? ?? '';
    final date = widget.event['date'] as String? ?? '';
    final venue = widget.event['venue'] as String? ?? '';
    final image = widget.event['image'] as String? ?? widget.event['imageUrl'] as String? ?? '';
    final status = widget.event['status'] as String? ?? '';
    final attendees = widget.event['attendees'] as int? ?? 0;
    final trending = widget.event['trending'] as bool? ?? false;
    final ticketUrl = widget.event['ticketUrl'] as String?;
    final isPast = EventDateUtils.isExploreItemPast(widget.event);

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
                child: Container(width: 48, height: 4, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'EVENT DETAILS',
                    style: AppTextStyles.display(20, color: AppColors.primary, letterSpacing: 0.05),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.secondary, size: 26),
                  ),
                ],
              ),
              if (image.isNotEmpty) ...[
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BeTherNetworkImage(url: image, fit: BoxFit.cover),
                      if (country.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: AppColors.secondary.withValues(alpha: 0.9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place, size: 14, color: AppColors.background),
                                const SizedBox(width: 6),
                                Text(
                                  country.toUpperCase(),
                                  style: AppTextStyles.display(12, color: AppColors.background),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
              Text(title, style: AppTextStyles.display(24, color: AppColors.secondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  border: const Border(
                    top: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
                    bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date.isNotEmpty) _DetailBlock(label: 'DATE', value: date),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailBlock(label: 'VENUE', value: venue),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailBlock(label: 'LOCATION', value: location),
                    ],
                    const SizedBox(height: 12),
                    _DetailBlock(label: 'ATTENDEES', value: '$attendees going'),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        EventDateUtils.statusLabel(status: status, isPast: isPast),
                        style: AppTextStyles.display(
                          12,
                          color: isPast ? AppColors.mutedForeground : AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isPast)
                      Container(
                        width: double.infinity,
                        height: 40,
                        alignment: Alignment.center,
                        color: AppColors.muted,
                        child: Text(
                          'PAST EVENT',
                          style: AppTextStyles.display(14, color: AppColors.mutedForeground),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _inCalendar ? AppColors.primary : AppColors.accent,
                            foregroundColor:
                                _inCalendar ? AppColors.primaryForeground : AppColors.accentForeground,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          onPressed: _calendarBusy ? null : _toggleCalendar,
                          child: _calendarBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _inCalendar ? 'ADDED TO CALENDAR' : 'ADD TO CALENDAR',
                                  style: AppTextStyles.display(
                                    14,
                                    color: _inCalendar
                                        ? AppColors.primaryForeground
                                        : AppColors.accentForeground,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: () => sharePostContent(
                      location: title.isNotEmpty ? title : location,
                      ticketUrl: ticketUrl,
                    ),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  const Spacer(),
                  if (!isPast && ticketUrl != null && ticketUrl.trim().isNotEmpty)
                    IconButton(
                      onPressed: () => openExternalUrl(context, ticketUrl),
                      icon: const Icon(Icons.link),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body(12, color: AppColors.mutedForeground, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.body(14, weight: FontWeight.w600)),
      ],
    );
  }
}
