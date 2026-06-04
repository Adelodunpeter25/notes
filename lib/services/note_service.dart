import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';
import 'sync_op_recorder.dart';

class NoteService {
  final NoteDao noteDao;
  final SyncOpRecorder _recorder;
  final _uuid = const Uuid();

  NoteService(this.noteDao, this._recorder);

  Stream<List<Note>> watchAllNotes(String userId) {
    return noteDao.watchAllNotes(userId);
  }

  Stream<List<Note>> watchNotesInFolder(String userId, String folderId) {
    return noteDao.watchNotesInFolder(userId, folderId);
  }

  Stream<List<Note>> watchTrashNotes(String userId) {
    return noteDao.watchTrashNotes(userId);
  }

  Stream<int> watchAllNotesCount(String userId) {
    return noteDao.watchAllNotesCount(userId);
  }

  Stream<int> watchTrashNotesCount(String userId) {
    return noteDao.watchTrashNotesCount(userId);
  }

  Stream<Map<String, int>> watchPerFolderCounts(String userId) {
    return noteDao.watchPerFolderCounts(userId);
  }

  Future<int> clearFolderFromNotes(String folderId) {
    return noteDao.clearFolderFromNotes(folderId);
  }

  Future<Note> createNote({
    required String title,
    required String content,
    required String userId,
    String? folderId,
  }) async {
    final noteId = _uuid.v4();
    final now = DateTime.now();
    final note = Note(
      id: noteId,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      folderId: folderId,
      userId: userId,
    );
    await noteDao.insertNote(
      NotesCompanion.insert(
        id: noteId,
        title: title,
        content: content,
        userId: userId,
        folderId: Value(folderId),
        createdAt: Value(now),
        updatedAt: Value(now),
        isPinned: const Value(false),
      ),
    );
    await _recorder.noteCreated(note);
    return note;
  }

  Future updateNote(Note note) async {
    await noteDao.updateNote(note);
    await _recorder.noteUpdated(note);
  }

  Future pinNote(Note note, bool isPinned) async {
    final updated = note.copyWith(isPinned: isPinned);
    await noteDao.updateNote(updated);
    await _recorder.notePinned(updated);
  }

  Future softDeleteNote(Note note) async {
    final updated = note.copyWith(deletedAt: Value(DateTime.now()));
    await noteDao.updateNote(updated);
    await _recorder.noteSoftDeleted(updated);
  }

  Future restoreNote(Note note) async {
    final updated = note.copyWith(deletedAt: const Value(null));
    await noteDao.updateNote(updated);
    await _recorder.noteRestored(updated);
  }

  Future moveNoteToFolder(Note note, String? folderId) async {
    final updated = note.copyWith(folderId: Value(folderId));
    await noteDao.updateNote(updated);
    await _recorder.noteMoved(updated);
  }

  Future<int> emptyTrash(String userId) async {
    final ids = await noteDao.listTrashNoteIds(userId);
    final count = await noteDao.emptyTrash(userId);
    if (ids.isNotEmpty) {
      await _recorder.noteHardDeletedIds(ids, userId);
    }
    return count;
  }

  Future<int> deleteNotePermanently(Note note) async {
    final count = await noteDao.deleteNotePermanently(note);
    await _recorder.noteHardDeleted(note);
    return count;
  }

  Future<void> autoDeleteEmptyNotes(String userId) async {
    final emptyNotes = await noteDao.findEmptyNotes(userId);
    for (final note in emptyNotes) {
      await noteDao.deleteNotePermanently(note);
      await _recorder.noteHardDeleted(note);
    }
  }
}
