import 'story.dart';

class SharedStory {
  final int id;
  final int storyId;
  final int userId;
  final bool isPublic;
  final DateTime createdAt;
  final Story? story;
  final SharedStoryUser? user;
  final int likeCount;
  final int commentCount;
  final bool hasLiked;

  String get storyTitle => story?.title ?? '';
  String get storyGenre => story?.genre ?? '';
  String? get storyContent => story?.chapters.isNotEmpty == true ? story!.chapters.map((c) => c.content).join('\n\n') : null;

  SharedStory({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.isPublic,
    required this.createdAt,
    this.story,
    this.user,
    this.likeCount = 0,
    this.commentCount = 0,
    this.hasLiked = false,
  });

  factory SharedStory.fromJson(Map<String, dynamic> json) {
    return SharedStory(
      id: json['id'],
      storyId: json['storyId'] ?? json['story_id'] ?? 0,
      userId: json['userId'] ?? json['user_id'] ?? 0,
      isPublic: json['isPublic'] ?? json['is_public'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      story: json['story'] != null ? Story.fromJson(json['story']) : null,
      user: json['user'] != null ? SharedStoryUser.fromJson(json['user']) : null,
      likeCount: json['likeCount'] ?? json['_count']?['likes'] ?? 0,
      commentCount: json['commentCount'] ?? json['_count']?['comments'] ?? 0,
      hasLiked: json['hasLiked'] ?? false,
    );
  }
}

class SharedStoryUser {
  final int id;
  final String username;
  final String? profileImage;

  SharedStoryUser({required this.id, required this.username, this.profileImage});

  factory SharedStoryUser.fromJson(Map<String, dynamic> json) {
    return SharedStoryUser(
      id: json['id'],
      username: json['username'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}
