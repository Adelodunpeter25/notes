import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'daos.dart';

part 'database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 3, max: 32)();
  TextColumn get email => text().unique()();
  TextColumn get password => text()(); // For sync; should be hashed in production
}

class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  IntColumn get userId => integer().references(Users, #id)();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 0, max: 255)();
  TextColumn get content => text()(); // JSON blob from appflowy_editor
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get folderId => integer().nullable().references(Folders, #id)();
  IntColumn get userId => integer().references(Users, #id)();
}

@DriftDatabase(tables: [Users, Folders, Notes], daos: [NoteDao, FolderDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'note_app_db.sqlite'));
    return NativeDatabase(file);
  });
}
