import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/explore/domain/explore_event.dart';
import '../../../features/feed/presentation/feed_providers.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import 'author_avatar.dart';

/// True when the signed-in user authored this post (id-only — never guess from RSVP).
bool isOwnEventByAuthorIds({
  required String myUserId,
  required String eventAuthorUserId,
  required ExploreAuthor? resolvedAuthor,
}) {
  if (myUserId.isEmpty) return false;
  if (eventAuthorUserId.isNotEmpty && eventAuthorUserId == myUserId) {
    return true;
  }
  final authorId = resolvedAuthor?.id.trim() ?? '';
  return authorId.isNotEmpty && authorId == myUserId;
}

/// Pull author for sheet header when list payloads omit a populated author.
Future<ExploreAuthor?> resolveEventSheetAuthor({
  required WidgetRef ref,
  required String postId,
  ExploreAuthor? existing,
}) async {
  if (existing != null && existing.username.trim().isNotEmpty) return existing;
  if (postId.trim().isEmpty) return null;
  try {
    final post = await ref.read(postsRepositoryProvider).fetchPost(postId);
    final username = post.author.username.trim();
    if (username.isEmpty) return null;
    return ExploreAuthor.fromFeedAuthor(
      id: post.author.id,
      username: username,
      displayName: post.author.displayName,
      avatarUrl: post.author.avatarUrl,
      badge: post.author.badge,
    );
  } catch (_) {
    return null;
  }
}

/// Tappable avatar + @username row for others' event sheets.
class EventSheetCreatorHeader extends StatelessWidget {
  const EventSheetCreatorHeader({
    super.key,
    required this.avatarUrl,
    required this.username,
    this.badge,
    required this.onTap,
  });

  final String avatarUrl;
  final String username;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final handle = username.trim();
    if (handle.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AuthorAvatar(
              avatarUrl: avatarUrl,
              username: handle,
              badge: badge,
              size: 36,
              interactive: false,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '@$handle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(
                  20,
                  color: AppColors.primary,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
