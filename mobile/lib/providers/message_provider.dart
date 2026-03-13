import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class MessageProvider extends ChangeNotifier {
  late final MessageService _messageService;
  final SocketService _socketService;

  List<Conversation> _conversations = [];
  final Map<int, List<Message>> _messages = {};
  bool _loading = false;
  int _unreadTotal = 0;

  MessageProvider(ApiService apiService, this._socketService) {
    _messageService = MessageService(apiService);
    _socketService.onMessageNew(_onMessageNew);
    _socketService.onMessageNotification(_onMessageNotification);
    _socketService.onMessageRead(_onMessageRead);
  }

  List<Conversation> get conversations => _conversations;
  bool get loading => _loading;
  List<Message> get messages => _activeMessages;
  int get unreadTotal => _unreadTotal;

  int _activeUserId = 0;
  final Map<int, bool> _hasMore = {};
  List<Message> get _activeMessages => _messages[_activeUserId] ?? [];

  List<Message> getMessagesFor(int userId) => _messages[userId] ?? [];
  bool hasMoreMessages(int userId) => _hasMore[userId] ?? true;

  void _onMessageNew(Map<String, dynamic> data) {
    final msg = Message.fromJson(data);
    // Add to the conversation's message list if we have it loaded
    final partnerId = msg.senderId == _activeUserId ? msg.senderId : msg.senderId;
    _messages.putIfAbsent(partnerId, () => []);
    // Avoid duplicate
    if (!_messages[partnerId]!.any((m) => m.id == msg.id)) {
      _messages[partnerId]!.insert(0, msg);
      notifyListeners();
    }
  }

  void _onMessageNotification(Map<String, dynamic> data) {
    final senderId = data['senderId'] as int?;
    if (senderId != null) {
      // Update specific conversation's unread count
      final idx = _conversations.indexWhere((c) => c.partnerId == senderId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(
          unreadCount: _conversations[idx].unreadCount + 1,
          lastMessage: data['content'] as String? ?? _conversations[idx].lastMessage,
          lastMessageAt: DateTime.now(),
        );
      }
    }
    _unreadTotal++;
    notifyListeners();
    // Also reload conversations to get proper ordering
    loadConversations();
  }

  void _onMessageRead(Map<String, dynamic> data) {
    // Partner has read our messages — update local message state
    final readBy = data['readBy'] as int?;
    final partnerId = data['partnerId'] as int?;
    if (readBy != null && partnerId != null) {
      final msgs = _messages[readBy];
      if (msgs != null) {
        for (var i = 0; i < msgs.length; i++) {
          if (!msgs[i].isRead && msgs[i].receiverId == readBy) {
            msgs[i] = Message(
              id: msgs[i].id,
              senderId: msgs[i].senderId,
              receiverId: msgs[i].receiverId,
              content: msgs[i].content,
              isRead: true,
              createdAt: msgs[i].createdAt,
            );
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> loadConversations() async {
    _loading = true;
    notifyListeners();

    try {
      _conversations = await _messageService.getConversations();
      _unreadTotal = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(int userId, {bool loadMore = false}) async {
    _activeUserId = userId;
    if (loadMore && !(_hasMore[userId] ?? true)) return;
    try {
      int? cursor;
      if (loadMore) {
        final existing = _messages[userId];
        if (existing != null && existing.isNotEmpty) {
          cursor = existing.last.id;
        }
      }
      final msgs = await _messageService.getMessages(userId, cursor: cursor);
      if (loadMore) {
        _messages.putIfAbsent(userId, () => []);
        _messages[userId]!.addAll(msgs);
      } else {
        _messages[userId] = msgs;
      }
      _hasMore[userId] = msgs.length >= 30;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> sendMessage(int userId, String content, {String? messageType, String? imageUrl}) async {
    try {
      final msg = await _messageService.sendMessage(userId, content, messageType: messageType, imageUrl: imageUrl);
      _messages.putIfAbsent(userId, () => []);
      _messages[userId]!.insert(0, msg);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markAsRead(int userId) async {
    try {
      await _messageService.markAsRead(userId);
      // Update unread count in conversations
      final idx = _conversations.indexWhere((c) => c.partnerId == userId);
      if (idx != -1) {
        final count = _conversations[idx].unreadCount;
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
        _unreadTotal -= count;
        if (_unreadTotal < 0) _unreadTotal = 0;
      }
      notifyListeners();
    } catch (_) {}
  }

  void addIncomingMessage(Message message) {
    final partnerId = message.senderId;
    _messages.putIfAbsent(partnerId, () => []);
    _messages[partnerId]!.insert(0, message);
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.removeMessageNew(_onMessageNew);
    _socketService.removeMessageNotification(_onMessageNotification);
    _socketService.removeMessageRead(_onMessageRead);
    super.dispose();
  }
}
