class Character {
  final int id;
  final int storyId;
  final int userId;
  final String name;
  final String? role;
  final String? backstory;
  final List<String> traits;
  final String? personality;
  final String? appearance;
  final DateTime createdAt;

  Character({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.name,
    this.role,
    this.backstory,
    this.traits = const [],
    this.personality,
    this.appearance,
    required this.createdAt,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      storyId: json['storyId'] ?? json['story_id'] ?? 0,
      userId: json['userId'] ?? json['user_id'] ?? 0,
      name: json['name'] ?? '',
      role: json['role'],
      backstory: json['backstory'],
      traits: (json['traits'] as List?)?.map((e) => e.toString()).toList() ?? [],
      personality: json['personality'],
      appearance: json['appearance'],
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'backstory': backstory,
      'traits': traits,
      'personality': personality,
      'appearance': appearance,
    };
  }
}
