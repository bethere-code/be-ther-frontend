/// Visibility rules for the feed / explore / search ⋮ menu.
enum FeedPostMoreMenuKind { none, ownUpcoming, ownPast, otherUpcoming }

FeedPostMoreMenuKind resolveFeedPostMoreMenu({
  required bool isOwnPost,
  required bool isPast,
}) {
  if (isOwnPost) {
    return isPast
        ? FeedPostMoreMenuKind.ownPast
        : FeedPostMoreMenuKind.ownUpcoming;
  }
  if (isPast) return FeedPostMoreMenuKind.none;
  return FeedPostMoreMenuKind.otherUpcoming;
}
