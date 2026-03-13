class Quest {
  final int id;
  final int userId;
  final String questType;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isClaimed;
  final int rewardXp;
  final DateTime date;
  final int? progress;
  final int? target;

  bool get claimed => isClaimed;
  String get type => questType;
  int get xpReward => rewardXp;

  Quest({
    required this.id,
    required this.userId,
    required this.questType,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isClaimed,
    required this.rewardXp,
    required this.date,
    this.progress,
    this.target,
  });

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'] ?? 0,
      questType: json['questType'] ?? json['quest_type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isClaimed: json['isClaimed'] ?? json['is_claimed'] ?? false,
      rewardXp: json['rewardXp'] ?? json['reward_xp'] ?? 0,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      progress: json['progress'],
      target: json['target'],
    );
  }
}
