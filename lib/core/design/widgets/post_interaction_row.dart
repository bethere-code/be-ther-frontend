import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/feed/presentation/feed_providers.dart';
import '../../../features/feed/presentation/widgets/feed_comments_sheet.dart';
import '../../../features/feed/presentation/widgets/feed_likes_sheet.dart';
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
    this.imageUrl,
    this.onInteractionChanged,
  });

  final String postId;
  final bool liked;
  final int likesCount;
  final int commentsCount;
  final String location;
  final String? caption;
  final String? ticketUrl;
  final String? imageUrl;
  final VoidCallback? onInteractionChanged;

  @override
  ConsumerState<PostInteractionRow> createState() => _PostInteractionRowState();
}

class _PostInteractionRowState extends ConsumerState<PostInteractionRow>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likesCount;
  late int _commentsCount;
  bool _likeBusy = false;

  late final AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostInteractionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liked != widget.liked ||
        oldWidget.likesCount != widget.likesCount ||
        oldWidget.commentsCount != widget.commentsCount) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _liked = widget.liked;
    _likesCount = widget.likesCount;
    _commentsCount = widget.commentsCount;
  }

  bool get _hasTicketUrl {
    final url = widget.ticketUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  Future<void> _toggleLike() async {
    if (widget.postId.isEmpty || _likeBusy) return;
    // Optimistic flip immediately.
    final prevLiked = _liked;
    final prevCount = _likesCount;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
      if (_likesCount < 0) _likesCount = 0;
      _likeBusy = true;
    });
    HapticFeedback.selectionClick();
    _heartCtrl.forward().then((_) => _heartCtrl.reverse());

    try {
      final liked =
          await ref.read(postsRepositoryProvider).toggleLike(widget.postId);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likesCount = prevCount + (liked ? 1 : -1);
        if (_likesCount < 0) _likesCount = 0;
      });
      widget.onInteractionChanged?.call();
    } catch (_) {
      // Revert on failure.
      if (!mounted) return;
      setState(() {
        _liked = prevLiked;
        _likesCount = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like')),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _openLikes() {
    if (widget.postId.isEmpty || _likesCount <= 0) return;
    showFeedLikesSheet(
      context: context,
      postId: widget.postId,
      initialCount: _likesCount,
    );
  }

  void _openComments() {
    if (widget.postId.isEmpty) return;
    showFeedCommentsSheet(
      context: context,
      postId: widget.postId,
      initialCount: _commentsCount,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() => _commentsCount = count);
        widget.onInteractionChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.25).animate(
            CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOutCubic),
          ),
          child: IconButton(
            icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
            color: _liked ? AppColors.primary : AppColors.foreground,
            onPressed: widget.postId.isEmpty ? null : _toggleLike,
          ),
        ),
        InkWell(
          onTap: _likesCount > 0 ? _openLikes : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(
              '$_likesCount',
              style: AppTextStyles.body(14, weight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: widget.postId.isEmpty ? null : _openComments,
        ),
        InkWell(
          onTap: widget.postId.isEmpty ? null : _openComments,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(
              '$_commentsCount',
              style: AppTextStyles.body(14, weight: FontWeight.w800),
            ),
          ),
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
          onPressed: widget.postId.isEmpty
              ? null
              : () async {
                  try {
                    await sharePostContent(
                      postId: widget.postId,
                      location: widget.location,
                      imageUrl: widget.imageUrl,
                      ticketUrl: widget.ticketUrl,
                      caption: widget.caption,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
        ),
      ],
    );
  }
}
