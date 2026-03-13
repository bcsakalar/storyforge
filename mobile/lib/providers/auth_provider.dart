import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SocketService _socketService;
  final PushNotificationService _pushService;
  late final AuthService _authService;

  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this._apiService, this._socketService, this._pushService) {
    _authService = AuthService(_apiService);
  }

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> tryAutoLogin() async {
    if (!_apiService.isAuthenticated) return;
    _loading = true;
    notifyListeners();

    _user = await _authService.getMe();
    if (_user != null) {
      _connectSocket();
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      _connectSocket();
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Bağlantı hatası';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.register(email, username, password);
      _connectSocket();
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Bağlantı hatası';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void _connectSocket() {
    final token = _apiService.token;
    if (token != null) {
      _socketService.connect(token);
    }
  }

  void logout() {
    _pushService.removeToken();
    _authService.logout();
    _socketService.disconnect();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
