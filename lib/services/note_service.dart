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

  Future<int> createNote({
    required String title,
    required String content,
    required String userId,
    String? folderId,
  }) {
    return noteDao.insertNote(
      NotesCompanion.insert(
        id: _uuid.v4(),
        title: title,
        content: content,
        userId: userId,
        folderId: Value(folderId),
      ),
    );
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
}
