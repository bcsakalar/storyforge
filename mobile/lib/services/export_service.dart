import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';

class ExportService {
  final ApiService _api;

  ExportService(this._api);

  Future<Uint8List> exportPdf(int storyId) async {
    final response = await _api.post(
      '/stories/$storyId/export/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> exportCoopPdf(int sessionId) async {
    final response = await _api.post(
      '/coop/$sessionId/export/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Map<String, dynamic>> downloadStory(int storyId) async {
    final response = await _api.get('/stories/$storyId/download');
    return response.data['story'];
  }
}
