import 'api_service.dart';

class NotificationApiService {
  final ApiService _api;

  NotificationApiService(this._api);

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _api.get('/notifications');
    return (response.data['notifications'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> markAsRead(int id) async {
    await _api.put('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _api.put('/notifications/read-all');
  }

  Future<void> registerPushToken(String token) async {
    await _api.post('/user/push-token', data: {'token': token});
  }

  Future<void> updateStreak() async {
    await _api.post('/user/streak');
  }
}
