class CoopSession {
  final int id;
  final int storyId;
  final int hostUserId;
  final int? guestUserId;
  final int currentTurn;
  final String status;
  final DateTime createdAt;
  final CoopUser? host;
  final CoopUser? guest;
  final CoopStoryInfo? story;

  int get hostId => hostUserId;
  int? get guestId => guestUserId;
  int get currentTurnId => currentTurn;
  String get genre => story?.genre ?? '';

  CoopSession({
    required this.id,
    required this.storyId,
    required this.hostUserId,
    this.guestUserId,
    required this.currentTurn,
    required this.status,
    required this.createdAt,
    this.host,
    this.guest,
    this.story,
  });

  factory CoopSession.fromJson(Map<String, dynamic> json) {
    return CoopSession(
      id: json['id'],
      storyId: json['storyId'] ?? json['story_id'] ?? 0,
      hostUserId: json['hostUserId'] ?? json['host_user_id'] ?? 0,
      guestUserId: json['guestUserId'] ?? json['guest_user_id'],
      currentTurn: json['currentTurn'] ?? json['current_turn'] ?? 1,
      status: json['status'] ?? 'WAITING',
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      host: json['host'] != null ? CoopUser.fromJson(json['host']) : null,
      guest: json['guest'] != null ? CoopUser.fromJson(json['guest']) : null,
      story: json['story'] != null ? CoopStoryInfo.fromJson(json['story']) : null,
    );
  }

  bool isMyTurn(int userId) {
    if (currentTurn == 1 && userId == hostUserId) return true;
    if (currentTurn == 2 && userId == guestUserId) return true;
    return false;
  }
}

class CoopUser {
  final int id;
  final String username;

  CoopUser({required this.id, required this.username});

  factory CoopUser.fromJson(Map<String, dynamic> json) {
    return CoopUser(id: json['id'], username: json['username'] ?? '');
  }
}

class CoopStoryInfo {
  final int id;
  final String title;
  final String genre;
  final List<Map<String, dynamic>> chapters;

  CoopStoryInfo({required this.id, required this.title, required this.genre, this.chapters = const []});

  factory CoopStoryInfo.fromJson(Map<String, dynamic> json) {
    return CoopStoryInfo(
      id: json['id'],
      title: json['title'] ?? '',
      genre: json['genre'] ?? '',
      chapters: (json['chapters'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)).toList() ?? [],
    );
  }
}

class CoopChapter {
  final int id;
  final String content;
  final int? authorId;
  final DateTime? createdAt;

  CoopChapter({required this.id, required this.content, this.authorId, this.createdAt});

  factory CoopChapter.fromJson(Map<String, dynamic> json) {
    return CoopChapter(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      authorId: json['authorId'] ?? json['author_id'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}
