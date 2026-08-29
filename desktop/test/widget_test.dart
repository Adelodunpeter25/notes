import 'package:desktop/app/app.dart';
import 'package:desktop/data/api/api_service.dart';
import 'package:desktop/data/database/daos.dart';
import 'package:desktop/data/database/database.dart';
import 'package:desktop/data/repositories/auth_service.dart';
import 'package:desktop/data/repositories/folder_service.dart';
import 'package:desktop/data/repositories/note_service.dart';
import 'package:desktop/data/sync/sync_op_recorder.dart';
import 'package:desktop/data/sync/sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots and renders the shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    final api = ApiService();
    final recorder = SyncOpRecorder(SyncOpDao(db));
    final noteService = NoteService(NoteDao(db), recorder);
    final folderService = FolderService(FolderDao(db), noteService, recorder);

    await tester.pumpWidget(NoteDesktopApp(
      db: db,
      authService: AuthService(db, api),
      folderService: folderService,
      noteService: noteService,
      syncService: SyncService(db, api, SyncOpDao(db)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

