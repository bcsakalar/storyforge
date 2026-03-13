import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/coop_session.dart';
import 'api_service.dart';

class CoopService {
  final ApiService _api;

  CoopService(this._api);

  Future<CoopSession> createSession(String genre, int guestUserId) async {
    final response = await _api.post('/coop/create', data: {'genre': genre, 'guestUserId': guestUserId});
    return CoopSession.fromJson(response.data['session']);
  }

  Future<CoopSession> joinSession(int sessionId) async {
    final response = await _api.post('/coop/$sessionId/join');
    return CoopSession.fromJson(response.data['session']);
  }

  Future<void> rejectSession(int sessionId) async {
    await _api.post('/coop/$sessionId/reject');
  }

  Future<CoopSession> getSession(int sessionId) async {
    final response = await _api.get('/coop/$sessionId');
    return CoopSession.fromJson(response.data['session']);
  }

  Future<CoopSession> makeChoice(int sessionId, int choiceId) async {
    final response = await _api.post('/coop/$sessionId/choose', data: {'choiceId': choiceId});
    return CoopSession.fromJson(response.data['session']);
  }

  Future<List<CoopSession>> getInvites() async {
    final response = await _api.get('/coop/invites');
    return (response.data['invites'] as List).map((s) => CoopSession.fromJson(s)).toList();
  }

  Future<List<CoopSession>> getSessions() async {
    final response = await _api.get('/coop/sessions');
    return (response.data['sessions'] as List).map((s) => CoopSession.fromJson(s)).toList();
  }

  Future<CoopSession> completeStory(int sessionId) async {
    final response = await _api.post('/coop/$sessionId/complete');
    return CoopSession.fromJson(response.data['session']);
  }

  /// Returns true if already shared
  Future<bool> shareStory(int sessionId) async {
    try {
      await _api.post('/coop/$sessionId/share');
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return true;
      rethrow;
    }
  }

  Future<Uint8List> exportPdf(int sessionId) async {
    final response = await _api.post('/coop/$sessionId/export/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
  }

  Future<String> getRecap(int sessionId) async {
    final response = await _api.get('/coop/$sessionId/recap');
    return response.data['recap'] ?? '';
  }

  Future<Map<String, dynamic>> getStoryTree(int sessionId) async {
    final response = await _api.get('/coop/$sessionId/tree');
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getCharacters(int sessionId) async {
    final response = await _api.get('/coop/$sessionId/characters');
    return (response.data['characters'] as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  Future<Map<String, dynamic>> addCharacter(int sessionId, {required String name, String? personality, String? appearance}) async {
    final response = await _api.post('/coop/$sessionId/characters', data: {
      'name': name,
      'personality': personality ?? '',
      'appearance': appearance ?? '',
    });
    return Map<String, dynamic>.from(response.data['character'] as Map);
  }

  Future<void> deleteCharacter(int sessionId, int characterId) async {
    await _api.delete('/coop/$sessionId/characters/$characterId');
  }
}
