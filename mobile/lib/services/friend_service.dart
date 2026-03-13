import '../models/friendship.dart';
import 'api_service.dart';

class FriendService {
  final ApiService _api;

  FriendService(this._api);

  Future<List<Friendship>> getFriends() async {
    final response = await _api.get('/friends');
    return (response.data['friends'] as List).map((f) => Friendship.fromJson(f)).toList();
  }

  Future<List<Friendship>> getPendingRequests() async {
    final response = await _api.get('/friends/pending');
    return (response.data['requests'] as List).map((f) => Friendship.fromJson(f)).toList();
  }

  Future<Friendship> sendRequest(String username) async {
    final response = await _api.post('/friends/request', data: {'username': username});
    return Friendship.fromJson(response.data['friendship']);
  }

  Future<Friendship> acceptRequest(int id) async {
    final response = await _api.post('/friends/accept/$id');
    return Friendship.fromJson(response.data['friendship']);
  }

  Future<Friendship> rejectRequest(int id) async {
    final response = await _api.post('/friends/reject/$id');
    return Friendship.fromJson(response.data['friendship']);
  }

  Future<void> removeFriend(int id) async {
    await _api.delete('/friends/$id');
  }

  Future<List<FriendUser>> searchUsers(String query) async {
    final response = await _api.get('/users/search', queryParameters: {'q': query});
    return (response.data['users'] as List).map((u) => FriendUser.fromJson(u)).toList();
  }
}
