class CommentAuthor {
  const CommentAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  factory CommentAuthor.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] as String?)?.trim() ?? '';
    final displayName = (json['displayName'] as String?)?.trim();
    return CommentAuthor(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      displayName:
          (displayName != null && displayName.isNotEmpty) ? displayName : username,
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.text,
    required this.likesCount,
    required this.liked,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String postId;
  final String text;
  final int likesCount;
  final bool liked;
  final DateTime createdAt;
  final CommentAuthor author;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    DateTime createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final authorRaw = json['author'];
    final author = authorRaw is Map<String, dynamic>
        ? CommentAuthor.fromJson(authorRaw)
        : authorRaw is Map
            ? CommentAuthor.fromJson(Map<String, dynamic>.from(authorRaw))
            : const CommentAuthor(
                id: '',
                username: '',
                displayName: 'User',
                avatarUrl: '',
              );

    return Comment(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      text: (json['text'] as String?)?.trim() ?? '',
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
      createdAt: createdAt,
      author: author,
    );
  }

  Comment copyWith({
    int? likesCount,
    bool? liked,
  }) {
    return Comment(
      id: id,
      postId: postId,
      text: text,
      likesCount: likesCount ?? this.likesCount,
      liked: liked ?? this.liked,
      createdAt: createdAt,
      author: author,
    );
  }
}

class CommentsPage {
  const CommentsPage({
    required this.items,
    required this.total,
    this.nextSkip,
  });

  final List<Comment> items;
  final int total;
  final int? nextSkip;
}

class LikesPage {
  const LikesPage({
    required this.items,
    required this.total,
    this.nextSkip,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int? nextSkip;
}
