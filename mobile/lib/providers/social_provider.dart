import 'package:flutter/material.dart';
import '../models/shared_story.dart';
import '../models/comment.dart';
import '../services/social_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class SocialProvider extends ChangeNotifier {
  late final SocialService _socialService;
  final SocketService? _socketService;

  List<SharedStory> _publicStories = [];
  List<SharedStory> _feed = [];
  List<Comment> _comments = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedGenre = '';

  SocialProvider(ApiService apiService, [this._socketService]) {
    _socialService = SocialService(apiService);
    _socketService?.onSocialLike(_onSocialLike);
    _socketService?.onSocialComment(_onSocialComment);
  }

  void _onSocialLike(Map<String, dynamic> data) {
    final sharedStoryId = data['sharedStoryId'] as int?;
    final likeCount = data['likeCount'] as int?;
    if (sharedStoryId == null || likeCount == null) return;

    // Update specific story's like count locally instead of reloading all
    final idx = _publicStories.indexWhere((s) => s.id == sharedStoryId);
    if (idx != -1) {
      final old = _publicStories[idx];
      _publicStories[idx] = SharedStory(
        id: old.id,
        storyId: old.storyId,
        userId: old.userId,
        isPublic: old.isPublic,
        createdAt: old.createdAt,
        story: old.story,
        user: old.user,
        likeCount: likeCount,
        commentCount: old.commentCount,
        hasLiked: old.hasLiked,
      );
      notifyListeners();
    }

    // Also update feed
    final feedIdx = _feed.indexWhere((s) => s.id == sharedStoryId);
    if (feedIdx != -1) {
      final old = _feed[feedIdx];
      _feed[feedIdx] = SharedStory(
        id: old.id,
        storyId: old.storyId,
        userId: old.userId,
        isPublic: old.isPublic,
        createdAt: old.createdAt,
        story: old.story,
        user: old.user,
        likeCount: likeCount,
        commentCount: old.commentCount,
        hasLiked: old.hasLiked,
      );
      notifyListeners();
    }
  }

  void _onSocialComment(Map<String, dynamic> data) {
    // Refresh comments if we're viewing the same story
    final sharedStoryId = data['sharedStoryId'];
    if (sharedStoryId != null) {
      loadComments(sharedStoryId);
    }
  }

  @override
  void dispose() {
    _socketService?.removeSocialLike(_onSocialLike);
    _socketService?.removeSocialComment(_onSocialComment);
    super.dispose();
  }

  List<SharedStory> get publicStories => _publicStories;
  List<SharedStory> get feed => _feed;
  List<Comment> get comments => _comments;
  bool get loading => _loading;
  bool get loadingPublic => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedGenre => _selectedGenre;

  Future<void> loadPublicStories({String sort = 'newest', int page = 1}) async {
    _loading = true;
    notifyListeners();

    try {
      _publicStories = await _socialService.getPublicStories(
        sort: sort,
        page: page,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        genre: _selectedGenre.isNotEmpty ? _selectedGenre : null,
      );
    } catch (_) {
      _error = 'Hikayeler yüklenemedi';
    }

    _loading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  void setSelectedGenre(String genre) {
    _selectedGenre = genre;
  }

  Future<void> loadFeed({int page = 1}) async {
    _loading = true;
    notifyListeners();

    try {
      _feed = await _socialService.getFeed(page: page);
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }

  Future<bool> shareStory(int storyId) async {
    try {
      return await _socialService.shareStory(storyId);
    } catch (_) {
      return false;
    }
  }

  Future<SharedStory?> loadDetail(int sharedStoryId) async {
    try {
      return await _socialService.getSharedStoryDetail(sharedStoryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadComments(int sharedStoryId) async {
    try {
      _comments = await _socialService.getComments(sharedStoryId);
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> toggleLike(int sharedStoryId) async {
    try {
      final result = await _socialService.toggleLike(sharedStoryId);
      // Update the specific story locally
      final liked = result['liked'] as bool? ?? false;
      final likeCount = result['likeCount'] as int?;
        final idx = _publicStories.indexWhere((s) => s.id == sharedStoryId);
        if (idx != -1) {
          final old = _publicStories[idx];
          _publicStories[idx] = SharedStory(
            id: old.id,
            storyId: old.storyId,
            userId: old.userId,
            isPublic: old.isPublic,
            createdAt: old.createdAt,
            story: old.story,
            user: old.user,
            likeCount: likeCount ?? old.likeCount,
            commentCount: old.commentCount,
            hasLiked: liked,
          );
          notifyListeners();
        }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<Comment>> getComments(int sharedStoryId) async {
    return _socialService.getComments(sharedStoryId);
  }

  Future<Comment?> addComment(int sharedStoryId, String content) async {
    try {
      final comment = await _socialService.addComment(sharedStoryId, content);
      // Reload comments to show the new one
      await loadComments(sharedStoryId);
      return comment;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteComment(int commentId) async {
    await _socialService.deleteComment(commentId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
