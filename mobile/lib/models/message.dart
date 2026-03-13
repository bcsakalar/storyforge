class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final String messageType;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  bool get isImage => messageType == 'image';

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'] ?? json['sender_id'] ?? 0,
      receiverId: json['receiverId'] ?? json['receiver_id'] ?? 0,
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? json['message_type'] ?? 'text',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
    );
  }
}

class Conversation {
  final int partnerId;
  final String partnerUsername;
  final String? partnerImage;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  int get userId => partnerId;
  String get username => partnerUsername;

  Conversation({
    required this.partnerId,
    required this.partnerUsername,
    this.partnerImage,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Handle nested partner object from API: { partner: {id, username}, lastMessage: {content, createdAt}, unreadCount }
    final partner = json['partner'];
    final lastMsg = json['lastMessage'];
    final bool isNestedLastMsg = lastMsg is Map;

    return Conversation(
      partnerId: partner is Map ? partner['id'] ?? 0 : (json['partnerId'] ?? json['partner_id'] ?? 0),
      partnerUsername: partner is Map ? partner['username'] ?? '' : (json['partnerUsername'] ?? json['partner_username'] ?? ''),
      partnerImage: partner is Map ? partner['profileImage'] : json['partnerImage'],
      lastMessage: isNestedLastMsg ? (lastMsg['content'] ?? '') : (lastMsg ?? ''),
      lastMessageAt: DateTime.parse(
        isNestedLastMsg
            ? (lastMsg['createdAt'] ?? DateTime.now().toIso8601String())
            : (json['lastMessageAt'] ?? json['last_message_at'] ?? DateTime.now().toIso8601String()),
      ),
      unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
    );
  }

  Conversation copyWith({
    int? partnerId,
    String? partnerUsername,
    String? partnerImage,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return Conversation(
      partnerId: partnerId ?? this.partnerId,
      partnerUsername: partnerUsername ?? this.partnerUsername,
      partnerImage: partnerImage ?? this.partnerImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
