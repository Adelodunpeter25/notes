import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'database/database.dart';
import 'database/daos.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'services/folder_service.dart';
import 'services/note_service.dart';
import 'layouts/desktop_layout.dart';
import 'pages/auth_pages.dart';
import 'utils/theme.dart';
import 'widgets/service_provider.dart';

import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  final api = ApiService();
  final auth = AuthService(db, api);
  final folderService = FolderService(FolderDao(db));
  final noteService = NoteService(NoteDao(db));
  
  // Seed the database and session for easy offline testing
  await _seedDatabase(db);
  
  // Check session persistence
  final token = await auth.getSessionToken();

  runApp(ServiceProvider(
    db: db,
    authService: auth,
    folderService: folderService,
    noteService: noteService,
    child: NoteApp(
      authService: auth,
      isLoggedIn: token != null,
    ),
  ));
}

Future<void> _seedDatabase(AppDatabase db) async {
  final users = await db.select(db.users).get();
  String userId;
  if (users.isEmpty) {
    userId = 'test_user_id';
    await db.into(db.users).insert(
      UsersCompanion.insert(
        id: userId,
        username: 'Test User',
        email: 'test@example.com',
      ),
    );
  } else {
    userId = users.first.id;
  }

  // Auto-login to bypass server requirement for testing
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('user_session_token') == null) {
    await prefs.setString('user_session_token', 'test_token');
  }

  final folders = await db.select(db.folders).get();
  if (folders.isEmpty) {
    const folder1Id = 'folder_personal';
    const folder2Id = 'folder_work';
    
    await db.into(db.folders).insert(
      FoldersCompanion.insert(
        id: folder1Id,
        name: 'Personal',
        userId: userId,
      ),
    );
    await db.into(db.folders).insert(
      FoldersCompanion.insert(
        id: folder2Id,
        name: 'Work',
        userId: userId,
      ),
    );
    
    // Seed notes
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'note_welcome',
        title: 'Welcome to Note',
        content: 'This is a sample note in the Personal folder.',
        userId: userId,
        folderId: const Value(folder1Id),
      ),
    );
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'note_shopping',
        title: 'Shopping List',
        content: 'Milk, Eggs, Bread, Butter.',
        userId: userId,
        folderId: const Value(null),
      ),
    );
  }
}

class NoteApp extends StatelessWidget {
  final AuthService authService;
  final bool isLoggedIn;

  const NoteApp({
    super.key, 
    required this.authService,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Note',
      theme: AppTheme.darkTheme, // Force dark mode as default
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn 
          ? const DesktopLayout() 
          : LoginPage(authService: authService),
    );
  }
}
