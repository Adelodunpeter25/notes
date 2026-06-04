import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../utils/note.dart';
import 'daos.dart';

part 'database.g.dart';

class Users extends Table {
  TextColumn get id => text()(); // Server UUID
  TextColumn get username => text().withLength(min: 3, max: 32)();
  TextColumn get email => text().unique()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()(); // Client or Server UUID
  TextColumn get name => text().withLength(min: 1, max: 64)();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get id => text()(); // Client or Server UUID
  TextColumn get title => text().withLength(min: 0, max: 255)();
  TextColumn get content => text()(); // JSON blob from appflowy_editor
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get folderId => text().nullable().references(Folders, #id)();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Queue of local mutations waiting to be pushed to the server.
///
/// Shape matches the server's SyncOperation contract
/// (see server/types/sync.ts):
///   id         — client-generated UUID (idempotency key)
///   opType     — 'upsert' | 'delete'
///   entityType — 'note' | 'folder'
///   entityId   — the entity's UUID
///   payload    — JSON snapshot of the entity at op time
///   updatedAt  — ISO timestamp, used by the server for conflict resolution
class SyncOps extends Table {
  TextColumn get id => text()();             // client UUID
  TextColumn get opType => text()();         // upsert | delete
  TextColumn get entityType => text()();     // note | folder
  TextColumn get entityId => text()();
  TextColumn get payload => text()();        // JSON snapshot
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Folders, Notes, SyncOps], daos: [NoteDao, FolderDao, SyncOpDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(syncOps);
        }
        if (from < 3) {
          await customStatement('DROP TABLE IF EXISTS ${syncOps.actualTableName}');
          await m.createTable(syncOps);
        }
        if (from < 4) {
          await customStatement('''
            CREATE VIRTUAL TABLE notes_fts USING fts5(
              note_id,
              title,
              plain_content,
              user_id
            )
          ''');
        }
      },
      onCreate: (m) async {
        await customStatement('''
          CREATE VIRTUAL TABLE notes_fts USING fts5(
            note_id,
            title,
            plain_content,
            user_id
          )
        ''');
      },
    );
  }

  /// Rebuilds the FTS index from all non-deleted notes.
  /// Called on startup to guarantee the index is in sync.
  Future<void> rebuildNoteFts() async {
    await customStatement('DELETE FROM notes_fts');
    final notesList = await select(notes).get();
    for (final note in notesList) {
      if (note.deletedAt != null) continue;
      final plainContent = NoteUtils.extractLines(note.content).join(' ');
      await upsertNoteFts(note.id, note.title, plainContent, note.userId);
    }
  }

  Future<void> upsertNoteFts(
      String noteId, String title, String plainContent, String userId) async {
    await customStatement(
      'INSERT OR REPLACE INTO notes_fts (note_id, title, plain_content, user_id) VALUES (?, ?, ?, ?)',
      [noteId, title, plainContent, userId],
    );
  }

  Future<void> deleteNoteFts(String noteId) async {
    await customStatement(
      'DELETE FROM notes_fts WHERE note_id = ?',
      [noteId],
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'note_app_db.sqlite'));
    return NativeDatabase(file);
  });
}
