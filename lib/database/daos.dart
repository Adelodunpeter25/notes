import 'package:drift/drift.dart';
import 'database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<Note>> watchAllNotes(String userId) {
    return (select(notes)..where((t) => t.userId.equals(userId))).watch();
  }

  Stream<List<Note>> watchNotesInFolder(String userId, String folderId) {
    return (select(notes)
          ..where((t) => t.userId.equals(userId) & t.folderId.equals(folderId)))
        .watch();
  }

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);
  Future updateNote(Note entry) => update(notes).replace(entry);
  Future deleteNote(Note entry) => delete(notes).delete(entry);
}

@DriftAccessor(tables: [Folders, Notes])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Stream<List<FolderWithCount>> watchFoldersWithCount(String userId) {
    return (select(folders)..where((t) => t.userId.equals(userId))).watch().map((rows) {
      return rows.map((folder) => FolderWithCount(folder, 0)).toList(); 
    });
  }

  // Optimized join for folder counts
  Stream<List<FolderWithCount>> watchFoldersWithNoteCount(String userId) {
    final noteCount = notes.id.count();
    final query = select(folders).join([
      leftOuterJoin(notes, notes.folderId.equalsExp(folders.id)),
    ])
      ..where(folders.userId.equals(userId))
      ..groupBy([folders.id]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return FolderWithCount(
          row.readTable(folders),
          row.read(noteCount) ?? 0,
        );
      }).toList();
    });
  }

  Future<int> insertFolder(FoldersCompanion entry) => into(folders).insert(entry);
  Future deleteFolder(Folder entry) => delete(folders).delete(entry);
}

class FolderWithCount {
  final Folder folder;
  final int noteCount;

  FolderWithCount(this.folder, this.noteCount);
}
