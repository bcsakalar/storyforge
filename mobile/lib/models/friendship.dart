class Friendship {
  final int id;
  final int senderId;
  final int receiverId;
  final String status;
  final DateTime createdAt;
  final FriendUser? sender;
  final FriendUser? receiver;
  final FriendUser? friend; // Direct friend reference from getFriends API

  Friendship({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.sender,
    this.receiver,
    this.friend,
  });

  /// Get the friend user regardless of API format
  FriendUser? getFriend(int? myId) {
    if (friend != null) return friend;
    if (myId != null) {
      return senderId == myId ? receiver : sender;
    }
    return sender ?? receiver;
  }

  factory Friendship.fromJson(Map<String, dynamic> json) {
    // Handle flat format from getFriends: { friendshipId, friend: {id, username} }
    if (json.containsKey('friendshipId') && json.containsKey('friend')) {
      final friendData = json['friend'];
      return Friendship(
        id: json['friendshipId'],
        senderId: 0,
        receiverId: 0,
        status: 'ACCEPTED',
        createdAt: DateTime.now(),
        friend: friendData != null ? FriendUser.fromJson(friendData) : null,
      );
    }

    // Standard friendship format from pending requests
    return Friendship(
      id: json['id'],
      senderId: json['senderId'] ?? json['sender_id'] ?? 0,
      receiverId: json['receiverId'] ?? json['receiver_id'] ?? 0,
      status: json['status'] ?? 'PENDING',
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      sender: json['sender'] != null ? FriendUser.fromJson(json['sender']) : null,
      receiver: json['receiver'] != null ? FriendUser.fromJson(json['receiver']) : null,
    );
  }
}

class FriendUser {
  final int id;
  final String username;
  final String? profileImage;

  FriendUser({required this.id, required this.username, this.profileImage});

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'],
      username: json['username'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}
