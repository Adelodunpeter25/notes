import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/database/database.dart';
import 'data/database/daos.dart';
import 'data/repositories/auth_service.dart';
import 'data/repositories/folder_service.dart';
import 'data/repositories/note_service.dart';
import 'data/api/api_service.dart';
import 'data/sync/sync_service.dart';
import 'data/sync/sync_op_recorder.dart';

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

  runApp(NoteDesktopApp(
    db: db,
    authService: auth,
    folderService: folderService,
    noteService: noteService,
    syncService: syncService,
  ));
}

