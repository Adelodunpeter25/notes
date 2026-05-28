import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'database/database.dart';
import 'database/daos.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'services/folder_service.dart';
import 'services/note_service.dart';
import 'services/sync_service.dart';
import 'layouts/desktop_layout.dart';
import 'pages/auth_pages.dart';
import 'utils/theme.dart';
import 'widgets/service_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  final api = ApiService();
  final auth = AuthService(db, api);
  final folderService = FolderService(FolderDao(db));
  final noteService = NoteService(NoteDao(db));
  final syncService = SyncService(db, api);
  
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
