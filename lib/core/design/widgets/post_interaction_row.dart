import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/feed/presentation/feed_providers.dart';
import '../../utils/link_utils.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

class PostInteractionRow extends ConsumerStatefulWidget {
  const PostInteractionRow({
    super.key,
    required this.postId,
    required this.liked,
    required this.likesCount,
    required this.commentsCount,
    required this.location,
    this.caption,
    this.ticketUrl,
    this.onInteractionChanged,
  });

  final String postId;
  final bool liked;
  final int likesCount;
  final int commentsCount;
  final String location;
  final String? caption;
  final String? ticketUrl;
  final VoidCallback? onInteractionChanged;

  @override
  ConsumerState<PostInteractionRow> createState() => _PostInteractionRowState();
}

class _PostInteractionRowState extends ConsumerState<PostInteractionRow> {
  late bool _liked;
  late int _likesCount;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(PostInteractionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liked != widget.liked || oldWidget.likesCount != widget.likesCount) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _liked = widget.liked;
    _likesCount = widget.likesCount;
  }

  bool get _hasTicketUrl {
    final url = widget.ticketUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  Future<void> _toggleLike() async {
    if (widget.postId.isEmpty || _likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final liked = await ref.read(postsRepositoryProvider).toggleLike(widget.postId);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likesCount += liked ? 1 : -1;
        if (_likesCount < 0) _likesCount = 0;
      });
      widget.onInteractionChanged?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like')),
        );
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
          color: _liked ? AppColors.primary : AppColors.foreground,
          onPressed: widget.postId.isEmpty || _likeBusy ? null : _toggleLike,
        ),
        Text(
          '$_likesCount',
          style: AppTextStyles.body(14, weight: FontWeight.w800),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comments coming soon')),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          '${widget.commentsCount}',
          style: AppTextStyles.body(14, weight: FontWeight.w800),
        ),
        const Spacer(),
        if (_hasTicketUrl)
          IconButton(
            icon: const Icon(Icons.link),
            color: AppColors.primary,
            tooltip: 'Buy tickets',
            onPressed: () => openExternalUrl(context, widget.ticketUrl),
          ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => sharePostContent(
            location: widget.location,
            ticketUrl: widget.ticketUrl,
            caption: widget.caption,
          ),
        ),
      ],
    );
  }
}
