import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/coop_session.dart';
import '../services/coop_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class CoopProvider extends ChangeNotifier {
  late final CoopService _coopService;
  final SocketService _socketService;

  List<CoopSession> _sessions = [];
  List<CoopSession> _invites = [];
  CoopSession? _currentSession;
  List<Map<String, dynamic>> _characters = [];
  bool _loading = false;
  bool _choosing = false;
  String? _error;

  CoopProvider(ApiService apiService, this._socketService) {
    _coopService = CoopService(apiService);
    _socketService.onCoopInvite(_onCoopInvite);
    _socketService.onCoopNewChapter(_onCoopNewChapter);
    _socketService.onCoopAccepted(_onCoopAccepted);
    _socketService.onCoopRejected(_onCoopRejected);
    _socketService.onCoopStatusChange(_onCoopStatusChange);
    _socketService.onCoopCharacterAdded(_onCoopCharacterAdded);
    _socketService.onCoopCharacterRemoved(_onCoopCharacterRemoved);
  }

  List<CoopSession> get sessions => _sessions;
  List<CoopSession> get invites => _invites;
  CoopSession? get currentSession => _currentSession;
  List<Map<String, dynamic>> get characters => _characters;
  bool get loading => _loading;
  bool get choosing => _choosing;
  String? get error => _error;

  Future<void> loadSessions() async {
    _loading = true;
    notifyListeners();
    try {
      _sessions = await _coopService.getSessions();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> loadInvites() async {
    try {
      _invites = await _coopService.getInvites();
      notifyListeners();
    } catch (_) {}
  }

  Future<CoopSession?> createSession(String genre, int guestUserId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _coopService.createSession(genre, guestUserId);
      _sessions.insert(0, session);
      _currentSession = session;
      _loading = false;
      notifyListeners();
      return session;
    } catch (e) {
      _error = 'Oturum oluşturulamadı';
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> joinSession(int sessionId) async {
    try {
      _currentSession = await _coopService.joinSession(sessionId);
      _invites.removeWhere((i) => i.id == sessionId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectSession(int sessionId) async {
    try {
      await _coopService.rejectSession(sessionId);
      _invites.removeWhere((i) => i.id == sessionId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadSession(int sessionId) async {
    _loading = true;
    notifyListeners();
    try {
      _currentSession = await _coopService.getSession(sessionId);
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<bool> makeChoice(int sessionId, int choiceId) async {
    _choosing = true;
    notifyListeners();
    try {
      _currentSession = await _coopService.makeChoice(sessionId, choiceId);
      _choosing = false;
      notifyListeners();
      return true;
    } catch (_) {
      _choosing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeStory(int sessionId) async {
    try {
      _currentSession = await _coopService.completeStory(sessionId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if already shared
  Future<bool> shareStory(int sessionId) async {
    try {
      return await _coopService.shareStory(sessionId);
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> exportPdf(int sessionId) async {
    try {
      return await _coopService.exportPdf(sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRecap(int sessionId) async {
    try {
      return await _coopService.getRecap(sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStoryTree(int sessionId) async {
    try {
      return await _coopService.getStoryTree(sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCharacters(int sessionId) async {
    try {
      _characters = await _coopService.getCharacters(sessionId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addCharacter(int sessionId, {required String name, String? personality, String? appearance}) async {
    try {
      final ch = await _coopService.addCharacter(sessionId, name: name, personality: personality, appearance: appearance);
      _characters.add(ch);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCharacter(int sessionId, int characterId) async {
    try {
      await _coopService.deleteCharacter(sessionId, characterId);
      _characters.removeWhere((c) => c['id'] == characterId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _onCoopInvite(Map<String, dynamic> data) {
    try {
      _invites.insert(0, CoopSession.fromJson(data));
    } catch (_) {
      loadInvites();
    }
    notifyListeners();
  }

  void _onCoopNewChapter(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (_currentSession != null && _currentSession!.id == sessionId) {
      loadSession(sessionId);
    }
  }

  void _onCoopAccepted(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (_currentSession != null && _currentSession!.id == sessionId) {
      loadSession(sessionId);
    }
    loadSessions();
  }

  void _onCoopRejected(Map<String, dynamic> data) {
    loadSessions();
  }

  void _onCoopStatusChange(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (_currentSession != null && _currentSession!.id == sessionId) {
      loadSession(sessionId);
    }
    loadSessions();
  }

  void _onCoopCharacterAdded(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (_currentSession != null && _currentSession!.id == sessionId) {
      final ch = data['character'];
      if (ch != null) {
        _characters.add(Map<String, dynamic>.from(ch as Map));
        notifyListeners();
      }
    }
  }

  void _onCoopCharacterRemoved(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (_currentSession != null && _currentSession!.id == sessionId) {
      final characterId = data['characterId'];
      if (characterId != null) {
        _characters.removeWhere((c) => c['id'] == characterId);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _socketService.removeCoopInvite(_onCoopInvite);
    _socketService.removeCoopNewChapter(_onCoopNewChapter);
    _socketService.removeCoopAccepted(_onCoopAccepted);
    _socketService.removeCoopRejected(_onCoopRejected);
    _socketService.removeCoopStatusChange(_onCoopStatusChange);
    _socketService.removeCoopCharacterAdded(_onCoopCharacterAdded);
    _socketService.removeCoopCharacterRemoved(_onCoopCharacterRemoved);
    super.dispose();
  }
}
