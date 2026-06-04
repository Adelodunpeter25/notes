import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart' hide User;
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final AppDatabase db;
  final ApiService api;
  static const String _sessionKey = 'user_session_token';

  AuthService(this.db, this.api);

  /// Registers a new user via the server
  Future<AuthResponse> registerUser(String username, String email, String password) async {
    final response = await api.post('/auth/signup', {
      'username': username,
      'email': email,
      'password': password,
    });
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final authResponse = AuthResponse.fromJson(response.data);
      await api.saveToken(authResponse.token);
      await _saveSession(authResponse.token);
      
      // Save user locally
      await db.into(db.users).insertOnConflictUpdate(
        UsersCompanion.insert(
          id: authResponse.user.id,
          username: authResponse.user.name ?? username,
          email: authResponse.user.email,
        ),
      );
      
      return authResponse;
    } else {
      throw Exception(response.data['error'] ?? 'Signup failed');
    }
  }

  /// Login a user via the server and save their session
  Future<AuthResponse> login(String email, String password) async {
    final response = await api.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(response.data);
      await api.saveToken(authResponse.token);
      await _saveSession(authResponse.token);
      
      // Save user locally — use email prefix as fallback if name is null/empty
      final displayName = (authResponse.user.name != null && authResponse.user.name!.isNotEmpty)
          ? authResponse.user.name!
          : authResponse.user.email.split('@').first;
      await db.into(db.users).insertOnConflictUpdate(
        UsersCompanion.insert(
          id: authResponse.user.id,
          username: displayName,
          email: authResponse.user.email,
        ),
      );

      return authResponse;
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

  /// Gets the currently logged-in user from the database
  Future<User?> getCurrentUser() async {
    final token = await getSessionToken();
    if (token == null) return null;
    final usersList = await db.select(db.users).get();
    if (usersList.isNotEmpty) {
      final u = usersList.first;
      return User(
        id: u.id,
        email: u.email,
        name: u.username,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// Logs out the user
  Future<void> logout() async {
    await api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
