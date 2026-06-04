Map<String, dynamic> readPostAuthor(Map<String, dynamic> item) {
  final author = item['authorId'];
  if (author is Map<String, dynamic>) return author;
  return const {};
}

String postAuthorUsername(Map<String, dynamic> item) {
  return readPostAuthor(item)['username'] as String? ?? '';
}

String? postAuthorBadge(Map<String, dynamic> item) {
  return readPostAuthor(item)['badge'] as String?;
}
