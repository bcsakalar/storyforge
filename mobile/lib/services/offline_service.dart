import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class OfflineService extends ChangeNotifier {
  static const String _storiesBox = 'offline_stories';
  static const String _metaBox = 'offline_meta';
  late Box _box;
  late Box _meta;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_storiesBox);
    _meta = await Hive.openBox(_metaBox);

    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);
      if (wasOnline != _isOnline) notifyListeners();
    });
  }

  // --- Single story cache (full content with chapters) ---

  Future<void> saveStoryOffline(int storyId, Map<String, dynamic> storyData) async {
    await _box.put('story_$storyId', storyData);
    await _meta.put('story_${storyId}_savedAt', DateTime.now().toIso8601String());
    notifyListeners();
  }

  Map<String, dynamic>? getOfflineStory(int storyId) {
    final raw = _box.get('story_$storyId');
    if (raw == null) return null;
    return _deepCast(raw);
  }

  Future<void> removeOfflineStory(int storyId) async {
    await _box.delete('story_$storyId');
    await _meta.delete('story_${storyId}_savedAt');
    notifyListeners();
  }

  bool isStoryDownloaded(int storyId) {
    return _box.containsKey('story_$storyId');
  }

  Set<int> get downloadedStoryIds {
    final ids = <int>{};
    for (final key in _box.keys) {
      if (key is String && key.startsWith('story_')) {
        final id = int.tryParse(key.substring(6));
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  List<Map<String, dynamic>> getAllOfflineStories() {
    final result = <Map<String, dynamic>>[];
    for (final key in _box.keys) {
      if (key is String && key.startsWith('story_')) {
        final raw = _box.get(key);
        if (raw != null) {
          result.add(_deepCast(raw));
        }
      }
    }
    return result;
  }

  // --- Story list cache (lightweight, for dashboard) ---

  Future<void> cacheStoryList(List<Map<String, dynamic>> stories) async {
    await _box.put('_story_list', stories);
    await _meta.put('_story_list_cachedAt', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedStoryList() {
    final raw = _box.get('_story_list');
    if (raw == null) return null;
    return (raw as List).map((e) => _deepCast(e)).toList();
  }

  /// Recursively cast Hive-returned dynamic maps to `Map<String, dynamic>`
  Map<String, dynamic> _deepCast(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) {
        if (v is Map) return MapEntry(k.toString(), _deepCast(v));
        if (v is List) return MapEntry(k.toString(), v.map((e) => e is Map ? _deepCast(e) : e).toList());
        return MapEntry(k.toString(), v);
      });
    }
    return {};
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
