import 'package:drift/native.dart';
import 'package:desktop/data/database/database.dart';
import 'package:desktop/data/database/daos.dart';
import 'package:desktop/data/repositories/folder_service.dart';
import 'package:desktop/data/repositories/note_service.dart';
import 'package:desktop/data/sync/sync_op_recorder.dart';

/// Creates a fresh in-memory Drift database seeded with the test user and
/// wires all core services on top of it — the Dart equivalent of the Swift
/// ServiceTests `setUp` (:memory: SQLite + service graph).
class TestCore {
  final AppDatabase db;
  final NoteDao noteDao;
  final FolderDao folderDao;
  final SyncOpDao syncOpDao;
  final SyncOpRecorder recorder;
  final NoteService noteService;
  final FolderService folderService;

  static const testUserId = 'user_test_123';

  TestCore._(this.db, this.noteDao, this.folderDao, this.syncOpDao,
      this.recorder, this.noteService, this.folderService);

  static Future<TestCore> create({bool seedUser = true}) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    if (seedUser) {
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: testUserId,
              username: 'testuser',
              email: 'test@example.com',
            ),
          );
    }
    final noteDao = db.noteDao;
    final folderDao = db.folderDao;
    final syncOpDao = db.syncOpDao;
    final recorder = SyncOpRecorder(syncOpDao);
    final noteService = NoteService(noteDao, recorder);
    final folderService = FolderService(folderDao, noteService, recorder);
    return TestCore._(
        db, noteDao, folderDao, syncOpDao, recorder, noteService, folderService);
  }

  Future<void> dispose() => db.close();
}
