import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
/// Each row is one op; the sync service drains the table on a successful push.
class SyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opType => text()();        // create | update | delete
  TextColumn get entityType => text()();    // note | folder
  TextColumn get entityId => text()();
  TextColumn get payload => text()();       // JSON-serialized entity snapshot
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Users, Folders, Notes, SyncOps], daos: [NoteDao, FolderDao, SyncOpDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        // Drop-and-recreate is fine for a local-only cache DB. Any ops that
        // hadn't been pushed yet are lost, but the local entities remain.
        if (from < 2) {
          await m.createTable(syncOps);
        }
      },
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
