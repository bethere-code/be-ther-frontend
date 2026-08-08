import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../feed_providers.dart';

Future<void> showFeedLikesSheet({
  required BuildContext context,
  required String postId,
  int initialCount = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _LikesSheet(postId: postId, initialCount: initialCount),
  );
}

class _LikesSheet extends ConsumerStatefulWidget {
  const _LikesSheet({required this.postId, required this.initialCount});

  final String postId;
  final int initialCount;

  @override
  ConsumerState<_LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends ConsumerState<_LikesSheet> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _total = 0;
  int _skip = 0;
  bool _loading = true;
  bool _loadingMore = false;
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
    super.dispose();
  }

  void _onScroll() {
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
          .fetchLikes(postId: widget.postId, skip: 0);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _skip = page.items.length;
        _hasMore = page.nextSkip != null;
        _loading = false;
      });
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
          .fetchLikes(postId: widget.postId, skip: _skip);
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

  void _openProfile(Map<String, dynamic> user) {
    final username = (user['username'] as String?)?.trim() ?? '';
    if (username.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(ProfileScreen.pathForUser(username));
  }

  @override
  Widget build(BuildContext context) {
    final title = _total == 1 ? '1 LIKE' : '$_total LIKES';
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
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
                    title,
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: AppColors.muted,
        highlightColor: AppColors.card,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 8,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: AppColors.muted),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 12,
                        width: 140,
                        child: ColoredBox(color: AppColors.muted),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        height: 10,
                        width: 90,
                        child: ColoredBox(color: AppColors.muted),
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
        child: Text(
          'No likes yet',
          style: AppTextStyles.body(15, color: AppColors.mutedForeground),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
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
        final user = _items[index];
        final username = user['username'] as String? ?? '';
        final name = user['displayName'] as String? ?? username;
        final avatar = user['avatarUrl'] as String? ?? '';
        return ListTile(
          onTap: () => _openProfile(user),
          leading: AuthorAvatar(
            avatarUrl: avatar,
            username: username,
            size: 40,
            interactive: false,
          ),
          title: Text(
            name,
            style: AppTextStyles.body(15, weight: FontWeight.w700),
          ),
          subtitle: username.isEmpty
              ? null
              : Text(
                  '@$username',
                  style: AppTextStyles.body(
                    13,
                    color: AppColors.mutedForeground,
                  ),
                ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
