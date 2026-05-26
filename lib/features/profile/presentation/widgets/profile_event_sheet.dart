import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/be_ther_network_image.dart';

class ProfileCalendarEvent {
  const ProfileCalendarEvent({
    required this.postId,
    required this.date,
    required this.location,
    required this.imageUrl,
    required this.status,
    required this.venue,
    this.ticketUrl,
    this.time,
    this.bookmarked = false,
  });

  final String postId;
  final DateTime date;
  final String location;
  final String imageUrl;
  final String status;
  final String venue;
  final String? ticketUrl;
  final String? time;
  final bool bookmarked;

  factory ProfileCalendarEvent.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    return ProfileCalendarEvent(
      postId: json['postId']?.toString() ?? '',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      location: json['location'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'going',
      venue: json['venue'] as String? ?? '',
      ticketUrl: json['ticketUrl'] as String?,
      time: json['time'] as String?,
      bookmarked: json['bookmarked'] as bool? ?? false,
    );
  }

  ProfileCalendarEvent copyWith({bool? bookmarked}) {
    return ProfileCalendarEvent(
      postId: postId,
      date: date,
      location: location,
      imageUrl: imageUrl,
      status: status,
      venue: venue,
      ticketUrl: ticketUrl,
      time: time,
      bookmarked: bookmarked ?? this.bookmarked,
    );
  }
}

Future<void> showProfileEventSheet({
  required BuildContext context,
  required ProfileCalendarEvent event,
  required bool showWishlist,
  required Future<bool> Function() onToggleWishlist,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProfileEventSheet(
      event: event,
      showWishlist: showWishlist,
      onToggleWishlist: onToggleWishlist,
    ),
  );
}

class _ProfileEventSheet extends StatefulWidget {
  const _ProfileEventSheet({
    required this.event,
    required this.showWishlist,
    required this.onToggleWishlist,
  });

  final ProfileCalendarEvent event;
  final bool showWishlist;
  final Future<bool> Function() onToggleWishlist;

  @override
  State<_ProfileEventSheet> createState() => _ProfileEventSheetState();
}

class _ProfileEventSheetState extends State<_ProfileEventSheet> {
  late bool _bookmarked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.event.bookmarked;
  }

  Color get _statusColor {
    if (widget.event.status == 'been') return AppColors.primary;
    if (widget.event.status == 'going') return AppColors.accent;
    return AppColors.muted;
  }

  Color get _statusFg {
    if (widget.event.status == 'been') return AppColors.primaryForeground;
    if (widget.event.status == 'going') return AppColors.accentForeground;
    return AppColors.foreground;
  }

  String get _statusLabel {
    if (widget.event.status == 'been') return 'BEEN';
    if (widget.event.status == 'going') return 'GOING';
    return 'INTERESTED';
  }

  Future<void> _toggleWishlist() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onToggleWishlist();
      if (mounted) setState(() => _bookmarked = saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTickets() async {
    final raw = widget.event.ticketUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMMEEEEd().format(widget.event.date);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.card,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.event.imageUrl.isNotEmpty)
                      BeTherNetworkImage(url: widget.event.imageUrl, fit: BoxFit.cover)
                    else
                      Container(color: AppColors.muted),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: Text(
                          _statusLabel,
                          style: AppTextStyles.display(14, color: _statusFg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.location,
                      style: AppTextStyles.display(28, color: AppColors.secondary, letterSpacing: 0.02),
                    ),
                    if (widget.event.venue.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.place, size: 16, color: AppColors.mutedForeground),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.event.venue,
                              style: AppTextStyles.body(15, weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AppColors.mutedForeground),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.event.time != null && widget.event.time!.isNotEmpty
                                ? '$dateLabel · ${widget.event.time}'
                                : dateLabel,
                            style: AppTextStyles.body(15, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (widget.showWishlist || (widget.event.ticketUrl?.isNotEmpty ?? false))
                      Row(
                        children: [
                          if (widget.showWishlist)
                            Expanded(
                              child: Material(
                                color: _bookmarked ? AppColors.primary : AppColors.muted,
                                child: InkWell(
                                  onTap: _busy ? null : _toggleWishlist,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
                                      boxShadow: const [BoxShadow(color: AppColors.border, offset: Offset(0, 4))],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                                          color: _bookmarked ? AppColors.primaryForeground : AppColors.foreground,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _bookmarked ? 'SAVED' : 'WISHLIST',
                                          style: AppTextStyles.display(
                                            15,
                                            color: _bookmarked ? AppColors.primaryForeground : AppColors.foreground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.showWishlist && (widget.event.ticketUrl?.isNotEmpty ?? false))
                            const SizedBox(width: 12),
                          if (widget.event.ticketUrl?.isNotEmpty ?? false)
                            Expanded(
                              child: Material(
                                color: AppColors.accent,
                                child: InkWell(
                                  onTap: _openTickets,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
                                      boxShadow: const [BoxShadow(color: AppColors.border, offset: Offset(0, 4))],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.open_in_new, color: AppColors.accentForeground),
                                        const SizedBox(width: 8),
                                        Text(
                                          'TICKETS',
                                          style: AppTextStyles.display(15, color: AppColors.accentForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.secondaryForeground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('CLOSE', style: AppTextStyles.display(18, color: AppColors.secondaryForeground)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
