import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'database/database.dart';
import 'database/daos.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'services/folder_service.dart';
import 'services/note_service.dart';
import 'services/sync_service.dart';
import 'services/sync_op_recorder.dart';
import 'services/quick_action_service.dart';
import 'services/reminder_service.dart';
import 'services/app_lock_service.dart';
import 'layouts/layout.dart';
import 'pages/auth_page.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/service_provider.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  final api = ApiService();
  final auth = AuthService(db, api);
  final syncOpDao = SyncOpDao(db);
  final recorder = SyncOpRecorder(syncOpDao);
  final noteService = NoteService(NoteDao(db), recorder);
  final folderService = FolderService(FolderDao(db), noteService, recorder);
  final syncService = SyncService(db, api, syncOpDao);
  final quickActionService = QuickActionService();
  final reminderService = ReminderService(db);
  final appLockService = AppLockService();
  
  quickActionService.initialize();
  // Re-arm reminder notifications after a reboot or plugin-storage wipe, and
  // drop reminders whose note was deleted. Reminders are local-only; they are
  // never part of the sync queue.
  await reminderService.rescheduleAll();

  // Check session persistence
  final token = await auth.getSessionToken();

  runApp(ServiceProvider(
    db: db,
    authService: auth,
    folderService: folderService,
    noteService: noteService,
    syncService: syncService,
    quickActionService: quickActionService,
    reminderService: reminderService,
    child: NoteApp(
      authService: auth,
      appLockService: appLockService,
      isLoggedIn: token != null,
    ),
  ));
}

class NoteApp extends StatelessWidget {
  final AuthService authService;
  final AppLockService appLockService;
  final bool isLoggedIn;

  const NoteApp({
    super.key, 
    required this.authService,
    required this.appLockService,
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      home: isLoggedIn
          ? AppLockGate(
              service: appLockService,
              child: const AppLayout(),
            )
          : AuthPage(authService: authService),
    );
  }
}
