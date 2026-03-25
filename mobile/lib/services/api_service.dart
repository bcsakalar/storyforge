import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://storyforge.berkecansakalar.com/api';
  static const String _webBaseUrl = 'http://localhost:3004/api';
  static const String _tokenKey = 'auth_token';

  late final Dio _dio;
  String? _token;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60), // LLM responses can be slow
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _token = null;
          _saveToken(null);
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> init() async {
    // Read token from secure storage (encrypted)
    if (!kIsWeb) {
      _token = await _secureStorage.read(key: _tokenKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    }
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_baseUrlKey);
    final baseUrl = savedUrl ?? (kIsWeb ? _webBaseUrl : _defaultBaseUrl);
    _dio.options.baseUrl = baseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    _dio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  String get baseUrl => _dio.options.baseUrl;

  String? get token => _token;

  bool get isAuthenticated => _token != null;

  void setToken(String? token) {
    _token = token;
    _saveToken(token);
  }

  Future<void> _saveToken(String? token) async {
    if (!kIsWeb) {
      if (token != null) {
        await _secureStorage.write(key: _tokenKey, value: token);
      } else {
        await _secureStorage.delete(key: _tokenKey);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(_tokenKey, token);
      } else {
        await prefs.remove(_tokenKey);
      }
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) => _dio.get(path, queryParameters: queryParameters);
  Future<Response> post(String path, {dynamic data, Options? options}) => _dio.post(path, data: data, options: options);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> delete(String path, {dynamic data}) => _dio.delete(path, data: data);

  Future<String> uploadFile(String path, String filePath, String fieldName) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(path, data: formData);
    return response.data['url'] as String;
  }

  /// Returns the full URL for a relative server path (e.g. /uploads/avatars/xxx.jpg)
  String getFullUrl(String relativePath) {
    final base = _dio.options.baseUrl;
    // Remove /api suffix to get server root
    final root = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
    return '$root$relativePath';
  }

  static String extractChapterAudio(dynamic data) {
    if (data is Map<String, dynamic>) {
      final audio = data['audio'];
      if (audio is String && audio.isNotEmpty) {
        return audio;
      }

      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw Exception(error);
      }
    }

    throw Exception('Ses verisi alınamadı');
  }

  Future<String> getChapterAudio(int storyId, int chapterNum) async {
    final response = await _dio.post(
      '/stories/$storyId/chapters/$chapterNum/tts',
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    );
    return extractChapterAudio(response.data);
  }
}
