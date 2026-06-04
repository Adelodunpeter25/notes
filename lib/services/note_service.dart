import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';

class NoteService {
  final NoteDao noteDao;
  final _uuid = const Uuid();

  NoteService(this.noteDao);

  Stream<List<Note>> watchAllNotes(String userId) {
    return noteDao.watchAllNotes(userId);
  }

  Stream<List<Note>> watchNotesInFolder(String userId, String folderId) {
    return noteDao.watchNotesInFolder(userId, folderId);
  }

  Stream<List<Note>> watchTrashNotes(String userId) {
    return noteDao.watchTrashNotes(userId);
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
    return note;
  }

  Future updateNote(Note note) {
    return noteDao.updateNote(note);
  }

  Future pinNote(Note note, bool isPinned) {
    return noteDao.updateNote(note.copyWith(isPinned: isPinned));
  }

  Future softDeleteNote(Note note) {
    return noteDao.updateNote(note.copyWith(deletedAt: Value(DateTime.now())));
  }

  Future restoreNote(Note note) {
    return noteDao.updateNote(note.copyWith(deletedAt: const Value(null)));
  }

  Future moveNoteToFolder(Note note, String? folderId) {
    return noteDao.updateNote(note.copyWith(folderId: Value(folderId)));
  }

  Future<int> emptyTrash(String userId) {
    return noteDao.emptyTrash(userId);
  }
}
