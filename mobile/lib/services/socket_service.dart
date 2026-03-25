import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

enum ConnectionState { connected, connecting, disconnected }

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  final ApiService _api;
  ConnectionState _connectionState = ConnectionState.disconnected;
  final Set<int> _onlineUserIds = {};

  SocketService(this._api);

  bool get isConnected => _socket?.connected ?? false;
  ConnectionState get connectionState => _connectionState;
  Set<int> get onlineUserIds => _onlineUserIds;
  bool isUserOnline(int userId) => _onlineUserIds.contains(userId);

  // Callbacks for providers to register
  final List<void Function(Map<String, dynamic>)> _messageNewCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _messageNotifCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _notificationCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _friendRequestCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _friendAcceptedCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopInviteCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopNewChapterCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopAcceptedCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopRejectedCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopStatusChangeCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopCharacterAddedCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _coopCharacterRemovedCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _socialLikeCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _socialCommentCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _notifReadCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _messageReadCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _typingStartCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _typingStopCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _userOnlineCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _userOfflineCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _storyChunkCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _storyCompleteCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _storyErrorCallbacks = [];
  final List<void Function(Map<String, dynamic>)> _storyStatusCallbacks = [];

  void onMessageNew(void Function(Map<String, dynamic>) cb) => _messageNewCallbacks.add(cb);
  void onMessageNotification(void Function(Map<String, dynamic>) cb) => _messageNotifCallbacks.add(cb);
  void onNotification(void Function(Map<String, dynamic>) cb) => _notificationCallbacks.add(cb);
  void onFriendRequest(void Function(Map<String, dynamic>) cb) => _friendRequestCallbacks.add(cb);
  void onFriendAccepted(void Function(Map<String, dynamic>) cb) => _friendAcceptedCallbacks.add(cb);
  void onCoopInvite(void Function(Map<String, dynamic>) cb) => _coopInviteCallbacks.add(cb);
  void onCoopNewChapter(void Function(Map<String, dynamic>) cb) => _coopNewChapterCallbacks.add(cb);
  void onCoopAccepted(void Function(Map<String, dynamic>) cb) => _coopAcceptedCallbacks.add(cb);
  void onCoopRejected(void Function(Map<String, dynamic>) cb) => _coopRejectedCallbacks.add(cb);
  void onCoopStatusChange(void Function(Map<String, dynamic>) cb) => _coopStatusChangeCallbacks.add(cb);
  void onCoopCharacterAdded(void Function(Map<String, dynamic>) cb) => _coopCharacterAddedCallbacks.add(cb);
  void onCoopCharacterRemoved(void Function(Map<String, dynamic>) cb) => _coopCharacterRemovedCallbacks.add(cb);
  void onSocialLike(void Function(Map<String, dynamic>) cb) => _socialLikeCallbacks.add(cb);
  void onSocialComment(void Function(Map<String, dynamic>) cb) => _socialCommentCallbacks.add(cb);
  void onNotificationRead(void Function(Map<String, dynamic>) cb) => _notifReadCallbacks.add(cb);
  void onMessageRead(void Function(Map<String, dynamic>) cb) => _messageReadCallbacks.add(cb);
  void onTypingStart(void Function(Map<String, dynamic>) cb) => _typingStartCallbacks.add(cb);
  void onTypingStop(void Function(Map<String, dynamic>) cb) => _typingStopCallbacks.add(cb);
  void onUserOnline(void Function(Map<String, dynamic>) cb) => _userOnlineCallbacks.add(cb);
  void onUserOffline(void Function(Map<String, dynamic>) cb) => _userOfflineCallbacks.add(cb);
  void onStoryChunk(void Function(Map<String, dynamic>) cb) => _storyChunkCallbacks.add(cb);
  void onStoryComplete(void Function(Map<String, dynamic>) cb) => _storyCompleteCallbacks.add(cb);
  void onStoryError(void Function(Map<String, dynamic>) cb) => _storyErrorCallbacks.add(cb);
  void onStoryStatus(void Function(Map<String, dynamic>) cb) => _storyStatusCallbacks.add(cb);

  void removeMessageNew(void Function(Map<String, dynamic>) cb) => _messageNewCallbacks.remove(cb);
  void removeMessageNotification(void Function(Map<String, dynamic>) cb) => _messageNotifCallbacks.remove(cb);
  void removeNotification(void Function(Map<String, dynamic>) cb) => _notificationCallbacks.remove(cb);
  void removeFriendRequest(void Function(Map<String, dynamic>) cb) => _friendRequestCallbacks.remove(cb);
  void removeFriendAccepted(void Function(Map<String, dynamic>) cb) => _friendAcceptedCallbacks.remove(cb);
  void removeCoopInvite(void Function(Map<String, dynamic>) cb) => _coopInviteCallbacks.remove(cb);
  void removeCoopNewChapter(void Function(Map<String, dynamic>) cb) => _coopNewChapterCallbacks.remove(cb);
  void removeCoopAccepted(void Function(Map<String, dynamic>) cb) => _coopAcceptedCallbacks.remove(cb);
  void removeCoopRejected(void Function(Map<String, dynamic>) cb) => _coopRejectedCallbacks.remove(cb);
  void removeCoopStatusChange(void Function(Map<String, dynamic>) cb) => _coopStatusChangeCallbacks.remove(cb);
  void removeCoopCharacterAdded(void Function(Map<String, dynamic>) cb) => _coopCharacterAddedCallbacks.remove(cb);
  void removeCoopCharacterRemoved(void Function(Map<String, dynamic>) cb) => _coopCharacterRemovedCallbacks.remove(cb);
  void removeSocialLike(void Function(Map<String, dynamic>) cb) => _socialLikeCallbacks.remove(cb);
  void removeSocialComment(void Function(Map<String, dynamic>) cb) => _socialCommentCallbacks.remove(cb);
  void removeNotificationRead(void Function(Map<String, dynamic>) cb) => _notifReadCallbacks.remove(cb);
  void removeMessageRead(void Function(Map<String, dynamic>) cb) => _messageReadCallbacks.remove(cb);
  void removeTypingStart(void Function(Map<String, dynamic>) cb) => _typingStartCallbacks.remove(cb);
  void removeTypingStop(void Function(Map<String, dynamic>) cb) => _typingStopCallbacks.remove(cb);
  void removeUserOnline(void Function(Map<String, dynamic>) cb) => _userOnlineCallbacks.remove(cb);
  void removeUserOffline(void Function(Map<String, dynamic>) cb) => _userOfflineCallbacks.remove(cb);
  void removeStoryChunk(void Function(Map<String, dynamic>) cb) => _storyChunkCallbacks.remove(cb);
  void removeStoryComplete(void Function(Map<String, dynamic>) cb) => _storyCompleteCallbacks.remove(cb);
  void removeStoryError(void Function(Map<String, dynamic>) cb) => _storyErrorCallbacks.remove(cb);
  void removeStoryStatus(void Function(Map<String, dynamic>) cb) => _storyStatusCallbacks.remove(cb);

  void connect(String token) {
    if (_socket?.connected == true) return;

    // Clean up any existing socket before reconnecting
    _socket?.dispose();
    _socket = null;

    _connectionState = ConnectionState.connecting;
    notifyListeners();

    final url = _api.baseUrl.replaceAll('/api', '');
    _socket = io.io(url, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .enableAutoConnect()
      .enableReconnection()
      .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected');
      _connectionState = ConnectionState.connected;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
      _connectionState = ConnectionState.disconnected;
      _onlineUserIds.clear();
      notifyListeners();
    });

    _socket!.on('reconnecting', (_) {
      _connectionState = ConnectionState.connecting;
      notifyListeners();
    });

    // Register all event handlers
    _socket!.on('message:new', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _messageNewCallbacks) { cb(d); }
    });

    _socket!.on('message:notification', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _messageNotifCallbacks) { cb(d); }
    });

    _socket!.on('notification:new', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _notificationCallbacks) { cb(d); }
    });

    _socket!.on('friend:request', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _friendRequestCallbacks) { cb(d); }
    });

    _socket!.on('friend:accepted', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _friendAcceptedCallbacks) { cb(d); }
    });

    _socket!.on('coop:invite', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopInviteCallbacks) { cb(d); }
    });

    _socket!.on('coop:newChapter', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopNewChapterCallbacks) { cb(d); }
    });

    _socket!.on('coop:accepted', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopAcceptedCallbacks) { cb(d); }
    });

    _socket!.on('coop:rejected', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopRejectedCallbacks) { cb(d); }
    });

    _socket!.on('coop:statusChange', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopStatusChangeCallbacks) { cb(d); }
    });

    _socket!.on('coop:characterAdded', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopCharacterAddedCallbacks) { cb(d); }
    });

    _socket!.on('coop:characterRemoved', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _coopCharacterRemovedCallbacks) { cb(d); }
    });

    _socket!.on('social:like', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _socialLikeCallbacks) { cb(d); }
    });

    _socket!.on('social:comment', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _socialCommentCallbacks) { cb(d); }
    });

    _socket!.on('notification:read', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _notifReadCallbacks) { cb(d); }
    });

    _socket!.on('message:read', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _messageReadCallbacks) { cb(d); }
    });

    _socket!.on('typing:start', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _typingStartCallbacks) { cb(d); }
    });

    _socket!.on('typing:stop', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _typingStopCallbacks) { cb(d); }
    });

    _socket!.on('user:online', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final uid = d['userId'] as int?;
      if (uid != null) _onlineUserIds.add(uid);
      for (final cb in _userOnlineCallbacks) { cb(d); }
      notifyListeners();
    });

    _socket!.on('user:offline', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final uid = d['userId'] as int?;
      if (uid != null) _onlineUserIds.remove(uid);
      for (final cb in _userOfflineCallbacks) { cb(d); }
      notifyListeners();
    });

    _socket!.on('user:onlineList', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final ids = (d['userIds'] as List?)?.cast<int>() ?? [];
      _onlineUserIds.clear();
      _onlineUserIds.addAll(ids);
      notifyListeners();
    });

    _socket!.on('story:chunk', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _storyChunkCallbacks) { cb(d); }
    });

    _socket!.on('story:complete', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _storyCompleteCallbacks) { cb(d); }
    });

    _socket!.on('story:error', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _storyErrorCallbacks) { cb(d); }
    });

    _socket!.on('story:status', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      for (final cb in _storyStatusCallbacks) { cb(d); }
    });
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void emitTypingStart(int partnerId) {
    _socket?.emit('typing:start', partnerId);
  }

  void emitTypingStop(int partnerId) {
    _socket?.emit('typing:stop', partnerId);
  }

  void emitCreateStoryStream(String genre, {String? mood, String? language}) {
    _socket?.emit('story:createStream', {
      'genre': genre,
      if (mood != null) 'mood': mood,
      if (language != null) 'language': language,
    });
  }

  void emitChooseStream(int storyId, int choiceId, {String? imageBase64}) {
    _socket?.emit('story:chooseStream', {
      'storyId': storyId,
      'choiceId': choiceId,
      if (imageBase64 != null) 'imageBase64': imageBase64,
    });
  }

  void joinChatRoom(int partnerId) {
    _socket?.emit('chat:join', partnerId);
  }

  void leaveChatRoom(int partnerId) {
    _socket?.emit('chat:leave', partnerId);
  }

  void joinCoopRoom(int sessionId) {
    _socket?.emit('coop:join', sessionId);
  }

  void leaveCoopRoom(int sessionId) {
    _socket?.emit('coop:leave', sessionId);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionState = ConnectionState.disconnected;
    _onlineUserIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageNewCallbacks.clear();
    _messageNotifCallbacks.clear();
    _notificationCallbacks.clear();
    _friendRequestCallbacks.clear();
    _friendAcceptedCallbacks.clear();
    _coopInviteCallbacks.clear();
    _coopNewChapterCallbacks.clear();
    _coopAcceptedCallbacks.clear();
    _coopRejectedCallbacks.clear();
    _coopStatusChangeCallbacks.clear();
    _coopCharacterAddedCallbacks.clear();
    _coopCharacterRemovedCallbacks.clear();
    _notifReadCallbacks.clear();
    _messageReadCallbacks.clear();
    _typingStartCallbacks.clear();
    _typingStopCallbacks.clear();
    _userOnlineCallbacks.clear();
    _userOfflineCallbacks.clear();
    _storyChunkCallbacks.clear();
    _storyCompleteCallbacks.clear();
    _storyErrorCallbacks.clear();
    super.dispose();
  }
}
