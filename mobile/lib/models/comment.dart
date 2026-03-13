class Comment {
  final int id;
  final int userId;
  final int sharedStoryId;
  final String content;
  final DateTime createdAt;
  final CommentUser? user;

  Comment({
    required this.id,
    required this.userId,
    required this.sharedStoryId,
    required this.content,
    required this.createdAt,
    this.user,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'] ?? 0,
      sharedStoryId: json['sharedStoryId'] ?? json['shared_story_id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      user: json['user'] != null ? CommentUser.fromJson(json['user']) : null,
    );
  }
}

class CommentUser {
  final int id;
  final String username;

  CommentUser({required this.id, required this.username});

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['id'],
      username: json['username'] ?? '',
    );
  }
}
