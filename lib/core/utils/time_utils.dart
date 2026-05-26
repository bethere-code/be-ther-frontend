String getRelativeTime(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inSeconds < 60) {
    return 'now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d';
  } else if (diff.inDays < 30) {
    return '${(diff.inDays / 7).floor()}w';
  } else {
    return '${(diff.inDays / 30).floor()}mo';
  }
}
