import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../../domain/comment.dart';
import '../feed_providers.dart';
import 'package:be_ther/core/ui/app_toast.dart';

Future<void> showFeedCommentsSheet({
  required BuildContext context,
  required String postId,
  int initialCount = 0,
  ValueChanged<int>? onCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _CommentsSheet(
      postId: postId,
      initialCount: initialCount,
      onCountChanged: onCountChanged,
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.initialCount,
    this.onCountChanged,
  });

  final String postId;
  final int initialCount;
  final ValueChanged<int>? onCountChanged;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _composerFieldKey = GlobalKey();
  final List<Comment> _items = [];

  int _total = 0;
  int _skip = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.initialCount;
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _emitCount() {
    widget.onCountChanged?.call(_total);
  }

  void _unfocusComposer() {
    if (_focus.hasFocus) _focus.unfocus();
  }

  /// Dismiss keyboard when interacting outside the composer (tap, scroll, sheet drag).
  void _unfocusIfOutsideComposer(Offset globalPosition) {
    if (!_focus.hasFocus) return;
    final box =
        _composerFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _unfocusComposer();
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.contains(globalPosition)) _unfocusComposer();
  }

  void _onScroll() {
    _unfocusComposer();
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 240) {
      return;
    }
    _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _skip = 0;
      _hasMore = true;
      _items.clear();
    });
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .fetchComments(postId: widget.postId, skip: 0);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _skip = page.items.length;
        _hasMore = page.nextSkip != null;
        _loading = false;
      });
      _emitCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .fetchComments(postId: widget.postId, skip: _skip);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _skip = _items.length;
        _hasMore = page.nextSkip != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending || widget.postId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final created = await ref
          .read(postsRepositoryProvider)
          .createComment(postId: widget.postId, text: text);
      if (!mounted) return;
      setState(() {
        _items.insert(0, created);
        _total += 1;
        _skip = _items.length;
        _composer.clear();
        _sending = false;
      });
      _emitCount();
      _focus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleLike(int index) async {
    final comment = _items[index];
    if (comment.id.isEmpty) return;
    final prev = comment;
    final nextLiked = !comment.liked;
    setState(() {
      _items[index] = comment.copyWith(
        liked: nextLiked,
        likesCount: (comment.likesCount + (nextLiked ? 1 : -1)).clamp(
          0,
          1 << 30,
        ),
      );
    });
    try {
      final result = await ref
          .read(postsRepositoryProvider)
          .toggleCommentLike(comment.id);
      if (!mounted) return;
      setState(() {
        _items[index] = comment.copyWith(
          liked: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = prev);
    }
  }

  Future<void> _confirmDelete(int index) async {
    final comment = _items[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'DELETE COMMENT?',
          style: AppTextStyles.display(22, color: AppColors.secondary),
        ),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(postsRepositoryProvider).deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _items.removeAt(index);
        _total = (_total - 1).clamp(0, 1 << 30);
        _skip = _items.length;
      });
      _emitCount();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  bool _isMine(Comment comment) {
    final me = ref.read(authNotifierProvider).user;
    if (me == null) return false;
    final myId = me['_id']?.toString() ?? me['id']?.toString() ?? '';
    if (myId.isNotEmpty && myId == comment.author.id) return true;
    final myUsername = (me['username'] as String?)?.trim() ?? '';
    return myUsername.isNotEmpty &&
        myUsername.toLowerCase() == comment.author.username.toLowerCase();
  }

  void _openProfile(CommentAuthor author) {
    if (author.username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(author.username));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final canSend = _composer.text.trim().isNotEmpty && !_sending;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _unfocusIfOutsideComposer(e.position),
      onPointerMove: (e) => _unfocusIfOutsideComposer(e.position),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedForeground.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _total <= 0 ? 'COMMENTS' : 'COMMENTS ($_total)',
                        style: AppTextStyles.display(
                          22,
                          color: AppColors.secondary,
                          letterSpacing: 0.04,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: AppDimens.border,
                color: AppColors.border,
              ),
              Expanded(child: _buildBody()),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border,
                      width: AppDimens.borderThin,
                    ),
                  ),
                  color: AppColors.card,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: _composerFieldKey,
                            controller: _composer,
                            focusNode: _focus,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onTapOutside: (_) => _unfocusComposer(),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (canSend) _send();
                            },
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.muted.withValues(
                                alpha: 0.55,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.border,
                                  width: AppDimens.border,
                                ),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.border,
                                  width: AppDimens.border,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: AppDimens.borderThick,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: canSend ? _send : null,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: canSend
                                      ? AppColors.primary
                                      : AppColors.mutedForeground,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _CommentsShimmerList();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(14, color: AppColors.destructive),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('RETRY')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No comments yet.\nBe the first to say something.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              15,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final comment = _items[index];
        final mine = _isMine(comment);
        return _CommentTile(
          comment: comment,
          isMine: mine,
          onAvatarTap: () => _openProfile(comment.author),
          onLike: () => _toggleLike(index),
          onDelete: mine ? () => _confirmDelete(index) : null,
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onAvatarTap,
    required this.onLike,
    this.onDelete,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback onAvatarTap;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: AuthorAvatar(
              avatarUrl: comment.author.avatarUrl,
              username: comment.author.username,
              size: 36,
              interactive: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: comment.author.displayName.isEmpty
                                  ? 'User'
                                  : comment.author.displayName,
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w800,
                                color: AppColors.foreground,
                              ),
                            ),
                            TextSpan(
                              text: '  ${getRelativeTime(comment.createdAt)}',
                              style: AppTextStyles.body(
                                12,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (v) {
                          if (v == 'delete') onDelete!();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w700,
                                color: AppColors.destructive,
                              ),
                            ),
                          ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: AppTextStyles.body(
                    14.5,
                    color: AppColors.foreground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
              child: Column(
                children: [
                  Icon(
                    comment.liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: comment.liked
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                  if (comment.likesCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likesCount}',
                      style: AppTextStyles.body(
                        11,
                        weight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsShimmerList extends StatelessWidget {
  const _CommentsShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.card,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.muted),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBar(width: 120, height: 12),
                    SizedBox(height: 8),
                    _ShimmerBar(width: double.infinity, height: 12),
                    SizedBox(height: 6),
                    _ShimmerBar(width: 180, height: 12),
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

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: height, color: AppColors.muted);
  }
}
