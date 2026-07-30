import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_text_styles.dart';
import '../../../../core/design/widgets/author_avatar.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../feed_providers.dart';

Future<void> showFeedAttendeesSheet({
  required BuildContext context,
  required String postId,
  int initialCount = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _AttendeesSheet(postId: postId, initialCount: initialCount),
  );
}

class _AttendeesSheet extends ConsumerStatefulWidget {
  const _AttendeesSheet({required this.postId, required this.initialCount});

  final String postId;
  final int initialCount;

  @override
  ConsumerState<_AttendeesSheet> createState() => _AttendeesSheetState();
}

class _AttendeesSheetState extends ConsumerState<_AttendeesSheet> {
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
          .fetchAttendees(postId: widget.postId, skip: 0);
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
      var message = e.toString().replaceFirst('Exception: ', '');
      // Production Fastify 404 when this route is not deployed yet.
      if (message == 'Not Found' || message.contains('not found')) {
        message = 'Could not load who is going. Pull to refresh, or try again shortly.';
      }
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .fetchAttendees(postId: widget.postId, skip: _skip);
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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    final title = _total == 1 ? '1 GOING' : '$_total GOING';

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
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
                    icon: const Icon(Icons.close, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: AppTextStyles.body(14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'No one has added this yet',
                                style: AppTextStyles.body(
                                  14,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final user = _items[index];
                                final username =
                                    user['username'] as String? ?? '';
                                final name =
                                    (user['displayName'] as String?)
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? user['displayName'] as String
                                    : username;
                                final avatar =
                                    user['avatarUrl'] as String? ?? '';
                                return ListTile(
                                  leading: AuthorAvatar(
                                    avatarUrl: avatar,
                                    username: username,
                                    size: 40,
                                  ),
                                  title: Text(
                                    name,
                                    style: AppTextStyles.body(
                                      15,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: username.isEmpty
                                      ? null
                                      : Text(
                                          '@$username',
                                          style: AppTextStyles.body(
                                            12,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                  onTap: username.isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          context.push(
                                            ProfileScreen.pathForUser(username),
                                          );
                                        },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
