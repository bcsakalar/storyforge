import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/friendship.dart';
import '../services/friend_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class FriendProvider extends ChangeNotifier {
  late final FriendService _friendService;
  final SocketService _socketService;

  List<Friendship> _friends = [];
  List<Friendship> _pendingRequests = [];
  List<FriendUser> _searchResults = [];
  bool _loading = false;
  String? _error;

  FriendProvider(ApiService apiService, this._socketService) {
    _friendService = FriendService(apiService);
    _socketService.onFriendRequest(_onFriendRequest);
    _socketService.onFriendAccepted(_onFriendAccepted);
  }

  List<Friendship> get friends => _friends;
  List<Friendship> get pendingRequests => _pendingRequests;
  List<FriendUser> get searchResults => _searchResults;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadFriends() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _friends = await _friendService.getFriends();
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Arkadaşlar yüklenemedi';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadPendingRequests() async {
    try {
      _pendingRequests = await _friendService.getPendingRequests();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> sendRequest(String username) async {
    try {
      await _friendService.sendRequest(username);
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'İstek gönderilemedi';
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptRequest(int id) async {
    try {
      await _friendService.acceptRequest(id);
      _pendingRequests.removeWhere((r) => r.id == id);
      await loadFriends();
    } catch (_) {}
  }

  Future<void> rejectRequest(int id) async {
    try {
      await _friendService.rejectRequest(id);
      _pendingRequests.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeFriend(int id) async {
    try {
      await _friendService.removeFriend(id);
      _friends.removeWhere((f) => f.id == id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> searchUsers(String query) async {
    if (query.length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      _searchResults = await _friendService.searchUsers(query);
      notifyListeners();
    } catch (_) {}
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _onFriendRequest(Map<String, dynamic> data) {
    // data: { friendshipId, sender: {id, username} }
    try {
      final friendship = Friendship.fromJson(data);
      // Deduplicate: skip if already in the list
      if (_pendingRequests.any((r) => r.id == friendship.id)) return;
      _pendingRequests.insert(0, friendship);
      notifyListeners();
    } catch (_) {}
  }

  void _onFriendAccepted(Map<String, dynamic> data) {
    // data: { friendshipId, friend: {id, username} }
    try {
      final friendship = Friendship.fromJson(data);
      // Deduplicate: skip if already in the list
      if (_friends.any((f) => f.id == friendship.id)) return;
      _friends.insert(0, friendship);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _socketService.removeFriendRequest(_onFriendRequest);
    _socketService.removeFriendAccepted(_onFriendAccepted);
    super.dispose();
  }
}
