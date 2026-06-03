import 'dart:io';
import 'package:flutter/material.dart';
import 'database/database.dart';
import 'database/daos.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'services/folder_service.dart';
import 'services/note_service.dart';
import 'services/sync_service.dart';
import 'layouts/layout.dart';
import 'pages/auth_page.dart';
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

  bool get _isMobile {
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mobile-first: use MaterialApp for iOS/Android
    if (_isMobile) {
      return MaterialApp(
        title: 'Note',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFFFFC107),
          useMaterial3: true,
          fontFamily: 'SF Pro Text',
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFFFFC107),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF000000),
          fontFamily: 'SF Pro Text',
        ),
        home: isLoggedIn
            ? const AppLayout()
            : AuthPage(authService: authService),
      );
    }

    // Desktop: use MacosApp (existing behavior)
    // Import macos_ui conditionally for desktop
    return _buildDesktopApp();
  }

  Widget _buildDesktopApp() {
    // For desktop, we still use MaterialApp but with desktop-optimized layout
    // This avoids the macos_ui dependency on mobile builds
    return MaterialApp(
      title: 'Note',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFFFFC107),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFFC107),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      ),
      home: isLoggedIn
          ? const AppLayout() // Use mobile layout everywhere for now (mobile-only focus)
          : AuthPage(authService: authService),
    );
  }
}
