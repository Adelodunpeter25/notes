import '../../domain/models/folder.dart';
import '../../domain/models/note.dart';

class NoteRepository {
  NoteRepository({String userId = 'local-user'}) : userId = userId;

  final String userId;
  final List<Note> _notes = <Note>[];
  final List<Folder> _folders = <Folder>[];

  List<Note> get activeNotes {
    final notes = _notes.where((note) => !note.isDeleted).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(notes);
  }

  List<Note> get trashNotes => List.unmodifiable(
        _notes.where((note) => note.isDeleted).toList()
          ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!)),
      );

  List<Folder> get folders => List.unmodifiable(
        _folders.where((folder) => !folder.isDeleted),
      );

  Note createNote({String? folderId}) {
    final now = DateTime.now();
    final note = Note(
      id: 'note-${now.microsecondsSinceEpoch}',
      title: 'Untitled',
      document: '',
      userId: userId,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
    );
    _notes.add(note);
    return note;
  }

  Folder createFolder(String name) {
    final folder = Folder(
      id: 'folder-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      userId: userId,
    );
    _folders.add(folder);
    return folder;
  }

  void updateNote(Note note) {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;
    _notes[index] = note;
  }

  void togglePinned(Note note) {
    updateNote(note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: DateTime.now(),
    ));
  }

  void moveToTrash(Note note) {
    updateNote(note.copyWith(
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  void restore(Note note) {
    updateNote(note.copyWith(
      clearDeletedAt: true,
      updatedAt: DateTime.now(),
    ));
  }

  void permanentlyDelete(Note note) {
    _notes.removeWhere((item) => item.id == note.id);
  }

  List<Note> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return activeNotes;
    return activeNotes.where((note) {
      return note.title.toLowerCase().contains(normalized) ||
          note.document.toLowerCase().contains(normalized);
    }).toList();
  }
}
