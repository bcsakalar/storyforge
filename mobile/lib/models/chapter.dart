class Chapter {
  final int id;
  final int storyId;
  final int chapterNumber;
  final String content;
  final List<Choice> choices;
  final int? selectedChoice;
  final String? imageData;
  final DateTime createdAt;

  Chapter({
    required this.id,
    required this.storyId,
    required this.chapterNumber,
    required this.content,
    required this.choices,
    this.selectedChoice,
    this.imageData,
    required this.createdAt,
  });

  bool get hasChoice => selectedChoice == null && choices.isNotEmpty;

  String? get selectedChoiceText {
    if (selectedChoice == null) return null;
    final choice = choices.where((c) => c.id == selectedChoice).firstOrNull;
    return choice?.text;
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    List<Choice> choices = [];
    if (json['choices'] != null) {
      choices = (json['choices'] as List)
          .map((c) => Choice.fromJson(c))
          .toList();
    }

    return Chapter(
      id: json['id'],
      storyId: json['storyId'] ?? json['story_id'] ?? 0,
      chapterNumber: json['chapterNumber'] ?? json['chapter_number'] ?? 0,
      content: json['content'] ?? '',
      choices: choices,
      selectedChoice: json['selectedChoice'] ?? json['selected_choice'],
      imageData: json['imageData'] ?? json['image_data'],
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.parse(json['createdAt'] ?? json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'chapterNumber': chapterNumber,
    'content': content,
    'choices': choices.map((c) => c.toJson()).toList(),
    'selectedChoice': selectedChoice,
    'imageData': imageData,
    'createdAt': createdAt.toIso8601String(),
  };
}

class Choice {
  final int id;
  final String text;

  Choice({required this.id, required this.text});

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      id: json['id'],
      text: json['text'],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}
