import 'package:crypt/crypt.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';

class AuthService {
  final AppDatabase db;

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
