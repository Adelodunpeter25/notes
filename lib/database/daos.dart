import 'dart:async';
import 'package:drift/drift.dart';
import 'database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<Note>> watchAllNotes(String userId) {
    return (select(notes)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchTrashNotes(String userId) {
    return (select(notes)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchNotesInFolder(String userId, String folderId) {
    return (select(notes)
          ..where((t) =>
              t.userId.equals(userId) &
              t.folderId.equals(folderId) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Reactive count of non-deleted notes for a user (replaces the
  /// FutureBuilder N+1 pattern in folders_view).
  Stream<int> watchAllNotesCount(String userId) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(userId)],
      readsFrom: {notes},
    ).watch().map((rows) => rows.first.read<int>('cnt'));
  }

  /// Reactive count of soft-deleted notes (trash).
  Stream<int> watchTrashNotesCount(String userId) {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ? AND deleted_at IS NOT NULL',
      variables: [Variable.withString(userId)],
      readsFrom: {notes},
    ).watch().map((rows) => rows.first.read<int>('cnt'));
  }

  /// Reactive per-folder counts, returned as a Map<folderId, count>.
  /// Folders with zero notes still appear (with count 0) because of the
  /// LEFT JOIN on folders.
  Stream<Map<String, int>> watchPerFolderCounts(String userId) {
    return customSelect(
      'SELECT f.id AS folder_id, COUNT(n.id) AS cnt '
      'FROM folders f LEFT JOIN notes n '
      'ON n.folder_id = f.id AND n.deleted_at IS NULL '
      'WHERE f.user_id = ? AND f.deleted_at IS NULL '
      'GROUP BY f.id',
      variables: [Variable.withString(userId)],
      readsFrom: {notes, db.folders},
    ).watch().map((rows) {
      return {for (final row in rows) row.read<String>('folder_id'): row.read<int>('cnt')};
    });
  }

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);
  Future updateNote(Note entry) => update(notes).replace(entry);
  Future<int> emptyTrash(String userId) {
    return (delete(notes)..where((t) => t.userId.equals(userId) & t.deletedAt.isNotNull())).go();
  }

  /// Returns the ids of every soft-deleted note belonging to [userId].
  /// Used to record per-note hard-delete ops before the local rows are wiped.
  Future<List<String>> listTrashNoteIds(String userId) {
    return (select(notes)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNotNull()))
        .get()
        .then((rows) => rows.map((r) => r.id).toList());
  }

  Future<int> deleteNotePermanently(Note entry) {
    return (delete(notes)..where((t) => t.id.equals(entry.id))).go();
  }

  /// Clears the folder reference on every note in the given folder.
  /// Used when a folder is soft-deleted so its notes don't become orphans.
  Future<int> clearFolderFromNotes(String folderId) {
    return (update(notes)..where((t) => t.folderId.equals(folderId)))
        .write(const NotesCompanion(folderId: Value(null)));
  }

  Future<List<Note>> findEmptyNotes(String userId) {
    return (select(notes)
          ..where((t) =>
              t.userId.equals(userId) &
              t.deletedAt.isNull()))
        .get();
  }

  /// Full-text search across title and plain-text content via the FTS index.
  Future<List<Note>> searchNotes(String userId, String query) async {
    final terms = query.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (terms.isEmpty) return [];
    final ftsQuery = terms.map((t) => '$t*').join(' AND ');

    final rows = await customSelect(
      'SELECT n.id, n.title, n.content, n.created_at, n.updated_at, '
      'n.is_pinned, n.folder_id, n.user_id, n.deleted_at '
      'FROM notes n '
      'INNER JOIN notes_fts fts ON n.id = fts.note_id '
      'WHERE notes_fts MATCH ? AND fts.user_id = ? AND n.deleted_at IS NULL '
      'ORDER BY rank',
      variables: [Variable.withString(ftsQuery), Variable.withString(userId)],
      readsFrom: {notes},
    ).get();

    return rows.map((row) => Note(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          content: row.read<String>('content'),
          createdAt: row.read<DateTime>('created_at'),
          updatedAt: row.read<DateTime>('updated_at'),
          isPinned: row.read<bool>('is_pinned'),
          folderId: row.read<String?>('folder_id'),
          userId: row.read<String>('user_id'),
          deletedAt: row.read<DateTime?>('deleted_at'),
        )).toList();
  }
}

@DriftAccessor(tables: [Folders, Notes])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Stream<List<FolderWithCount>> watchFoldersWithNoteCount(String userId) {
    final noteCount = notes.id.count();
    final query = select(folders).join([
      leftOuterJoin(notes, notes.folderId.equalsExp(folders.id)),
    ]);
    
    query.addColumns([noteCount]);
    
    query
      ..where(folders.userId.equals(userId) & folders.deletedAt.isNull())
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
  Future updateFolder(Folder entry) => update(folders).replace(entry);
  Future<int> deleteFolder(Folder entry) => (delete(folders)..where((t) => t.id.equals(entry.id))).go();
}

class FolderWithCount {
  final Folder folder;
  final int noteCount;

  FolderWithCount(this.folder, this.noteCount);
}

/// Queue for local mutations pending push to the server.
///
/// Shape matches the server's SyncOperation contract; rows are drained FIFO
/// by [pullPending] and removed by [deleteOps] once the server acks their ids.
@DriftAccessor(tables: [SyncOps])
class SyncOpDao extends DatabaseAccessor<AppDatabase> with _$SyncOpDaoMixin {
  SyncOpDao(super.db);

  Future<int> insertOp({
    required String id,
    required String opType,
    required String entityType,
    required String entityId,
    required String payload,
    required DateTime updatedAt,
  }) {
    return into(syncOps).insert(SyncOpsCompanion.insert(
      id: id,
      opType: opType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      updatedAt: Value(updatedAt),
    ));
  }

  /// Returns all pending ops ordered by insertion time (updatedAt asc).
  Future<List<SyncOp>> pullPending() {
    return (select(syncOps)..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
        .get();
  }

  /// Remove the ops whose ids were acked by the server (processedOpIds).
  Future<int> deleteOps(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(syncOps)..where((t) => t.id.isIn(ids))).go();
  }

  Future<int> countPending() {
    return customSelect(
      'SELECT COUNT(*) AS cnt FROM sync_ops',
      readsFrom: {syncOps},
    ).get().then((rows) => rows.first.read<int>('cnt'));
  }
}
