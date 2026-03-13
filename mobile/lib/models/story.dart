import 'chapter.dart';

class Story {
  final int id;
  final int userId;
  final String title;
  final String genre;
  final String summary;
  final String? mood;
  final bool isActive;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Chapter> chapters;
  final int chapterCount;

  Story({
    required this.id,
    required this.userId,
    required this.title,
    required this.genre,
    required this.summary,
    this.mood,
    required this.isActive,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    required this.chapters,
    required this.chapterCount,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    List<Chapter> chapters = [];
    if (json['chapters'] != null) {
      chapters = (json['chapters'] as List)
          .map((c) => Chapter.fromJson(c))
          .toList();
    }

    int count = chapters.length;
    if (json['_count'] != null && json['_count']['chapters'] != null) {
      count = json['_count']['chapters'];
    }

    return Story(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'] ?? 0,
      title: json['title'],
      genre: json['genre'],
      summary: json['summary'] ?? '',
      mood: json['mood'],
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.parse(json['createdAt'] ?? json['created_at'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null || json['updated_at'] != null
          ? DateTime.parse(json['updatedAt'] ?? json['updated_at'])
          : DateTime.now(),
      chapters: chapters,
      chapterCount: count,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'genre': genre,
    'summary': summary,
    'mood': mood,
    'isActive': isActive,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'chapters': chapters.map((c) => c.toJson()).toList(),
    '_count': {'chapters': chapterCount},
  };
}
