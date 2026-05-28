import 'package:crypt/crypt.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';

class AuthService {
  final AppDatabase db;
  static const String _sessionKey = 'user_session_token';

  AuthService(this.db);

  /// Hashes a password using SHA-256 with a salt (via crypt package)
  String hashPassword(String password) {
    return Crypt.sha256(password).toString();
  }

  /// Verifies if a plain password matches a stored hash
  bool verifyPassword(String password, String hash) {
    return Crypt(hash).match(password);
  }

  /// Registers a new user with a hashed password
  Future<int> registerUser(String username, String email, String password) async {
    final hashedPassword = hashPassword(password);
    return await db.into(db.users).insert(
          UsersCompanion.insert(
            username: username,
            email: email,
            password: hashedPassword,
          ),
        );
  }

  /// Login a user and save their session locally
  Future<User?> login(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user != null && verifyPassword(password, user.password)) {
      await _saveSession(user.id.toString()); // Saving ID as a "token" for now
      return user;
    }
    return null;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Finds a user by email
  Future<User?> getUserByEmail(String email) async {
    return await (db.select(db.users)..where((u) => u.email.equals(email)))
        .getSingleOrNull();
  }

  /// Finds a user by ID
  Future<User?> getUserById(int id) async {
    return await (db.select(db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }
}
