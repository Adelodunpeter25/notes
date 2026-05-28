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

  Future deleteNote(Note note) {
    return noteDao.deleteNote(note);
  }
}
