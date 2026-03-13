import 'api_service.dart';

class ModerationService {
  final ApiService _api;

  ModerationService(this._api);

  Future<void> blockUser(int userId) async {
    await _api.post('/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _api.delete('/users/$userId/block');
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final response = await _api.get('/users/blocked');
    return (response.data['users'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> reportContent({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    await _api.post('/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (description != null) 'description': description,
    });
  }

  Future<void> addBookmark(int sharedStoryId) async {
    await _api.post('/bookmarks/$sharedStoryId');
  }

  Future<void> removeBookmark(int sharedStoryId) async {
    await _api.delete('/bookmarks/$sharedStoryId');
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final response = await _api.get('/bookmarks');
    return (response.data['bookmarks'] as List).cast<Map<String, dynamic>>();
  }
}
