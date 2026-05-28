import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import 'api_service.dart';

class AuthService {
  final AppDatabase db;
  final ApiService api;
  static const String _sessionKey = 'user_session_token';

  AuthService(this.db, this.api);

  /// Registers a new user via the server
  Future<void> registerUser(String username, String email, String password) async {
    final response = await api.post('/auth/signup', {
      'username': username,
      'email': email,
      'password': password,
    });
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = response.data['token'];
      if (token != null) {
        await api.saveToken(token);
      }
    } else {
      throw Exception(response.data['error'] ?? 'Signup failed');
    }
  }

  /// Login a user via the server and save their session
  Future<void> login(String email, String password) async {
    final response = await api.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final token = response.data['token'];
      if (token != null) {
        await api.saveToken(token);
        await _saveSession(token); // Mirror to local session key
      }
    } else {
      throw Exception(response.data['error'] ?? 'Login failed');
    }
  }

  /// Saves the user session locally
  Future<void> _saveSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, token);
  }

  /// Checks if a user is logged in
  Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  /// Logs out the user
  Future<void> logout() async {
    await api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
