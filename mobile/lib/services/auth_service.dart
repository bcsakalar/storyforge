import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<User> register(String email, String username, String password) async {
    final response = await _api.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    _api.setToken(response.data['token']);
    return User.fromJson(response.data['user']);
  }

  Future<User> login(String email, String password) async {
    final response = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    _api.setToken(response.data['token']);
    return User.fromJson(response.data['user']);
  }

  Future<User?> getMe() async {
    try {
      final response = await _api.get('/auth/me');
      return User.fromJson(response.data['user']);
    } catch (_) {
      return null;
    }
  }

  void logout() {
    _api.setToken(null);
  }
}
