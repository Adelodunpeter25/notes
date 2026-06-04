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

@DriftDatabase(tables: [Users, Folders, Notes], daos: [NoteDao, FolderDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      if (!await dbFolder.exists()) {
        await dbFolder.create(recursive: true);
      }
      final file = File(p.join(dbFolder.path, 'note_app_db.sqlite'));
      return NativeDatabase(file);
    } catch (e) {
      // Log error to console for easier debugging of native lib issues
      print('Error opening database: $e');
      rethrow;
    }
  });
}
