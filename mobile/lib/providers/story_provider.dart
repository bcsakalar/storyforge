import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/story.dart';
import '../services/api_service.dart';
import '../services/story_service.dart';
import '../services/socket_service.dart';
import '../services/offline_service.dart';

class StoryProvider extends ChangeNotifier {
  late final StoryService _storyService;
  final SocketService _socketService;
  final OfflineService _offlineService;

  List<Story> _stories = [];
  Story? _currentStory;
  bool _loading = false;
  bool _choosing = false;
  String? _error;
  bool _isStreaming = false;
  String _streamingText = '';
  String _agentStatus = '';

  StoryProvider(ApiService apiService, this._socketService, this._offlineService) {
    _storyService = StoryService(apiService);
    _socketService.onStoryChunk(_onStoryChunk);
    _socketService.onStoryComplete(_onStoryComplete);
    _socketService.onStoryError(_onStoryError);
    _socketService.onStoryStatus(_onStoryStatus);
  }

  List<Story> get stories => _stories;
  Story? get currentStory => _currentStory;
  bool get loading => _loading;
  bool get choosing => _choosing;
  String? get error => _error;
  bool get isStreaming => _isStreaming;
  String get streamingText => _streamingText;
  String get agentStatus => _agentStatus;

  Future<void> loadStories() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _stories = await _storyService.getStories();
      // Cache story list for offline use
      _offlineService.cacheStoryList(_stories.map((s) => s.toJson()).toList());
    } on DioException catch (e) {
      // Offline fallback: load from cache
      final cached = _offlineService.getCachedStoryList();
      if (cached != null && cached.isNotEmpty) {
        _stories = cached.map((s) => Story.fromJson(s)).toList();
      } else {
        _error = e.response?.data?['error'] ?? 'Hikayeler yüklenemedi';
      }
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadStory(int id) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _currentStory = await _storyService.getStory(id);
      // Auto-update offline cache if this story was downloaded
      if (_offlineService.isStoryDownloaded(id) && _currentStory != null) {
        _offlineService.saveStoryOffline(id, _currentStory!.toJson());
      }
    } on DioException catch (e) {
      // Offline fallback: load from cache
      final cached = _offlineService.getOfflineStory(id);
      if (cached != null) {
        _currentStory = Story.fromJson(cached);
      } else {
        _error = e.response?.data?['error'] ?? 'Hikaye yüklenemedi';
      }
    }

    _loading = false;
    notifyListeners();
  }

  Future<Story?> createStory(String genre, {String? mood, String? language}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final story = await _storyService.createStory(genre, mood: mood, language: language);
      _stories.insert(0, story);
      _currentStory = story;
      _loading = false;
      notifyListeners();
      return story;
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Hikaye oluşturulamadı';
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> makeChoice(int storyId, int choiceId, {String? imageBase64}) async {
    _choosing = true;
    _error = null;
    notifyListeners();

    try {
      _currentStory = await _storyService.makeChoice(
        storyId,
        choiceId,
        imageBase64: imageBase64,
      );
      _choosing = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Seçim yapılamadı';
      _choosing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteStory(int id) async {
    try {
      await _storyService.deleteStory(id);
      _stories.removeWhere((s) => s.id == id);
      if (_currentStory?.id == id) _currentStory = null;
      notifyListeners();
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Hikaye silinemedi';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Extracts readable story text from accumulated JSON streaming chunks
  String extractStoryText(String accumulated) {
    const key = '"storyText":"';
    final start = accumulated.indexOf(key);
    if (start == -1) return '';
    var text = accumulated.substring(start + key.length);
    // Find end of storyText value
    final endPatterns = ['","choices"', '","mood"', '","chapterSummary"'];
    int endIdx = text.length;
    for (final pat in endPatterns) {
      final idx = text.indexOf(pat);
      if (idx != -1 && idx < endIdx) endIdx = idx;
    }
    text = text.substring(0, endIdx);
    // Unescape JSON string
    text = text
        .replaceAll('\\n', '\n')
        .replaceAll('\\"', '"')
        .replaceAll('\\\\', '\\');
    return text;
  }

  void _onStoryChunk(Map<String, dynamic> data) {
    final text = data['text'] as String? ?? '';
    _streamingText += text;
    _agentStatus = 'writing';
    notifyListeners();
  }

  void _onStoryStatus(Map<String, dynamic> data) {
    _agentStatus = data['status'] as String? ?? '';
    notifyListeners();
  }

  void _onStoryComplete(Map<String, dynamic> data) {
    _isStreaming = false;
    _streamingText = '';
    _agentStatus = '';
    if (data['story'] != null) {
      final story = Story.fromJson(Map<String, dynamic>.from(data['story'] as Map));
      _currentStory = story;
      final idx = _stories.indexWhere((s) => s.id == story.id);
      if (idx >= 0) {
        _stories[idx] = story;
      } else {
        _stories.insert(0, story);
      }
    }
    _choosing = false;
    _loading = false;
    notifyListeners();
  }

  void _onStoryError(Map<String, dynamic> data) {
    _isStreaming = false;
    _streamingText = '';
    _agentStatus = '';
    _error = data['error'] as String? ?? 'Bir hata oluştu';
    _choosing = false;
    _loading = false;
    notifyListeners();
  }

  void createStoryStream(String genre, {String? mood, String? language}) {
    _loading = true;
    _isStreaming = true;
    _streamingText = '';
    _agentStatus = 'memory';
    _error = null;
    notifyListeners();
    _socketService.emitCreateStoryStream(genre, mood: mood, language: language);
  }

  void makeChoiceStream(int storyId, int choiceId, {String? imageBase64}) {
    _choosing = true;
    _isStreaming = true;
    _streamingText = '';
    _agentStatus = 'memory';
    _error = null;
    notifyListeners();
    _socketService.emitChooseStream(storyId, choiceId, imageBase64: imageBase64);
  }

  // --- Offline download management ---

  OfflineService get offlineService => _offlineService;

  bool isStoryDownloaded(int storyId) => _offlineService.isStoryDownloaded(storyId);

  Future<void> downloadStory(int storyId) async {
    try {
      final story = await _storyService.getStory(storyId);
      await _offlineService.saveStoryOffline(storyId, story.toJson());
      notifyListeners();
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'İndirilemedi';
      notifyListeners();
    }
  }

  Future<void> removeDownload(int storyId) async {
    await _offlineService.removeOfflineStory(storyId);
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.removeStoryChunk(_onStoryChunk);
    _socketService.removeStoryComplete(_onStoryComplete);
    _socketService.removeStoryError(_onStoryError);
    _socketService.removeStoryStatus(_onStoryStatus);
    super.dispose();
  }
}
