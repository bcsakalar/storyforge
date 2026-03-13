class Achievement {
  final int id;
  final String key;
  final String title;
  final String description;
  final String icon;
  final String category;
  final int threshold;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.threshold,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    // Could be from user achievements (with pivot) or available achievements
    final achievement = json['achievement'] ?? json;
    return Achievement(
      id: achievement['id'] ?? json['id'],
      key: achievement['key'] ?? json['key'] ?? '',
      title: achievement['title'] ?? json['title'] ?? '',
      description: achievement['description'] ?? json['description'] ?? '',
      icon: achievement['icon'] ?? json['icon'] ?? '🏆',
      category: achievement['category'] ?? json['category'] ?? '',
      threshold: achievement['threshold'] ?? json['threshold'] ?? 0,
      unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
    );
  }
}
