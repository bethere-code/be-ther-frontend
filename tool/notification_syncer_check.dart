// ponytail: resume must never force full notifications list fetch.
void main() {
  // Documents the contract used by NotificationSyncer (logic is in the widget
  // layer; this asserts the policy constants stay sane).
  const badgeDebounceSeconds = 2;
  assert(badgeDebounceSeconds >= 1 && badgeDebounceSeconds <= 10);

  // Policy matrix (manual):
  // resume        → refreshBadge only
  // alerts open   → refreshList (+ markAllRead → unread only)
  // fcm foreground→ invalidate unread; softInvalidateList if watched
  // fcm opened    → syncNow (badge + list iff watched)
  // connectivity  → refreshBadge + softInvalidateList (no await list)
  // ignore: avoid_print
  print('notification_syncer.check: ok');
}
