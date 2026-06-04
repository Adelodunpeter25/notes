import 'package:flutter/material.dart';
import 'database/database.dart';
import 'database/daos.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'services/folder_service.dart';
import 'services/note_service.dart';
import 'services/sync_service.dart';
import 'services/sync_op_recorder.dart';
import 'layouts/layout.dart';
import 'pages/auth_page.dart';
import 'widgets/service_provider.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  await db.rebuildNoteFts();
  final api = ApiService();
  final auth = AuthService(db, api);
  final syncOpDao = SyncOpDao(db);
  final recorder = SyncOpRecorder(syncOpDao);
  final noteService = NoteService(NoteDao(db), recorder);
  final folderService = FolderService(FolderDao(db), noteService, recorder);
  final syncService = SyncService(db, api, syncOpDao);
  
  // Check session persistence
  final token = await auth.getSessionToken();

  runApp(ServiceProvider(
    db: db,
    authService: auth,
    folderService: folderService,
    noteService: noteService,
    syncService: syncService,
    child: NoteApp(
      authService: auth,
      isLoggedIn: token != null,
    ),
  ));
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
    return MaterialApp(
      title: 'Note',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: isLoggedIn
          ? const AppLayout()
          : AuthPage(authService: authService),
    );
  }
}
