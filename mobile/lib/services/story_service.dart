import '../models/story.dart';
import 'api_service.dart';

class StoryService {
  final ApiService _api;

  StoryService(this._api);

  Future<List<Story>> getStories() async {
    final response = await _api.get('/stories');
    final list = response.data['stories'] as List;
    return list.map((s) => Story.fromJson(s)).toList();
  }

  Future<Story> getStory(int id) async {
    final response = await _api.get('/stories/$id');
    return Story.fromJson(response.data['story']);
  }

  Future<Story> createStory(String genre, {String? mood, String? language}) async {
    final data = <String, dynamic>{'genre': genre};
    if (mood != null) data['mood'] = mood;
    if (language != null) data['language'] = language;
    final response = await _api.post('/stories', data: data);
    return Story.fromJson(response.data['story']);
  }

  Future<Story> makeChoice(int storyId, int choiceId, {String? imageBase64}) async {
    final data = <String, dynamic>{'choiceId': choiceId};
    if (imageBase64 != null) {
      data['imageBase64'] = imageBase64;
    }
    final response = await _api.post('/stories/$storyId/choose', data: data);
    return Story.fromJson(response.data['story']);
  }

  Future<void> deleteStory(int id) async {
    await _api.delete('/stories/$id');
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await _api.get('/genres');
    return (response.data['genres'] as List).cast<Map<String, dynamic>>();
  }
}
