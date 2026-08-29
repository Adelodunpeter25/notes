import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

import '../data/database/database.dart';
import '../data/repositories/auth_service.dart';
import '../data/repositories/folder_service.dart';
import '../data/repositories/note_service.dart';
import '../data/sync/sync_service.dart';
import '../features/auth/auth_page.dart';
import '../features/shell/shell_page.dart';
import 'service_scope.dart';
import 'theme.dart';

/// Root widget. Builds the MaterialApp and routes between the auth page and
/// the main three-pane shell based on the persisted session.
class NoteDesktopApp extends StatelessWidget {
  final AppDatabase db;
  final AuthService authService;
  final FolderService folderService;
  final NoteService noteService;
  final SyncService syncService;

  const NoteDesktopApp({
    super.key,
    required this.db,
    required this.authService,
    required this.folderService,
    required this.noteService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceScope(
      db: db,
      authService: authService,
      folderService: folderService,
      noteService: noteService,
      syncService: syncService,
      child: MaterialApp(
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
        supportedLocales: const [Locale('en', 'US')],
        home: SessionGate(authService: authService),
      ),
    );
  }
}

/// Waits for the persisted session before showing either the shell or auth.
class SessionGate extends StatefulWidget {
  final AuthService authService;

  const SessionGate({super.key, required this.authService});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture =
        widget.authService.getSessionToken().then((token) => token != null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true
            ? const ShellPage()
            : const AuthPage();
      },
    );
  }
}
