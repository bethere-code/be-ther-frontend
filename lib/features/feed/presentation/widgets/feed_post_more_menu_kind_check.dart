// Run: dart run lib/features/feed/presentation/widgets/feed_post_more_menu_kind_check.dart
import 'feed_post_more_menu_kind.dart';

void main() {
  assert(
    resolveFeedPostMoreMenu(isOwnPost: true, isPast: false) ==
        FeedPostMoreMenuKind.ownUpcoming,
  );
  assert(
    resolveFeedPostMoreMenu(isOwnPost: true, isPast: true) ==
        FeedPostMoreMenuKind.ownPast,
  );
  assert(
    resolveFeedPostMoreMenu(isOwnPost: false, isPast: false) ==
        FeedPostMoreMenuKind.otherUpcoming,
  );
  assert(
    resolveFeedPostMoreMenu(isOwnPost: false, isPast: true) ==
        FeedPostMoreMenuKind.none,
  );
  // ignore: avoid_print
  print('feed_post_more_menu_kind_check: ok');
}
