import 'package:dio/dio.dart';
import '../models/shared_story.dart';
import '../models/comment.dart';
import 'api_service.dart';

class SocialService {
  final ApiService _api;

  SocialService(this._api);

  Future<bool> shareStory(int storyId, {bool isPublic = true}) async {
    try {
      await _api.post('/stories/$storyId/share', data: {'isPublic': isPublic});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return false;
      rethrow;
    }
  }

  Future<void> unshareStory(int storyId) async {
    await _api.delete('/stories/$storyId/share');
  }

  Future<List<SharedStory>> getPublicStories({String sort = 'newest', int page = 1, String? search, String? genre}) async {
    final params = <String, dynamic>{'sort': sort, 'page': page.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (genre != null && genre.isNotEmpty) params['genre'] = genre;
    final response = await _api.get('/stories/public', queryParameters: params);
    return (response.data['stories'] as List).map((s) => SharedStory.fromJson(s)).toList();
  }

  Future<List<SharedStory>> getFeed({int page = 1}) async {
    final response = await _api.get('/stories/feed', queryParameters: {'page': page.toString()});
    return (response.data['stories'] as List).map((s) => SharedStory.fromJson(s)).toList();
  }

  Future<Map<String, dynamic>> toggleLike(int sharedStoryId) async {
    final response = await _api.post('/shared/$sharedStoryId/like');
    return response.data;
  }

  Future<void> unlikeStory(int sharedStoryId) async {
    await _api.delete('/shared/$sharedStoryId/like');
  }

  Future<List<Comment>> getComments(int sharedStoryId) async {
    final response = await _api.get('/shared/$sharedStoryId/comments');
    return (response.data['comments'] as List).map((c) => Comment.fromJson(c)).toList();
  }

  Future<Comment> addComment(int sharedStoryId, String content) async {
    final response = await _api.post('/shared/$sharedStoryId/comments', data: {'content': content});
    return Comment.fromJson(response.data['comment']);
  }

  Future<void> deleteComment(int commentId) async {
    await _api.delete('/comments/$commentId');
  }

  Future<SharedStory> getSharedStoryDetail(int sharedStoryId) async {
    final response = await _api.get('/shared/$sharedStoryId');
    return SharedStory.fromJson(response.data['story']);
  }
}
