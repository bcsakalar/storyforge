class User {
  final int id;
  final String email;
  final String username;
  final String? profileImage;
  final String language;
  final String theme;
  final int fontSize;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.profileImage,
    this.language = 'tr',
    this.theme = 'dark',
    this.fontSize = 16,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      profileImage: json['profileImage'],
      language: json['language'] ?? 'tr',
      theme: json['theme'] ?? 'dark',
      fontSize: json['fontSize'] ?? 16,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}
