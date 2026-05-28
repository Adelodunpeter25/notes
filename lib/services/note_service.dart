import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/daos.dart';

class NoteService {
  final NoteDao noteDao;

  NoteService(this.noteDao);

  Stream<List<Note>> watchAllNotes(int userId) {
    return noteDao.watchAllNotes(userId);
  }

  Stream<List<Note>> watchNotesInFolder(int userId, int folderId) {
    return noteDao.watchNotesInFolder(userId, folderId);
  }

  Future<int> createNote({
    required String title,
    required String content,
    required int userId,
    int? folderId,
  }) {
    return noteDao.insertNote(
      NotesCompanion.insert(
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

  Future deleteNote(Note note) {
    return noteDao.deleteNote(note);
  }
}
