import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/data/repositories/note_repository.dart';

void main() {
  test('creates, searches, and moves a note to trash', () {
    final repository = NoteRepository();
    final note = repository.createNote();
    note.title = 'Apple Pie';
    note.document = 'Buy apples';
    repository.updateNote(note);

    expect(repository.search('apple'), hasLength(1));
    repository.moveToTrash(note);
    expect(repository.activeNotes, isEmpty);
    expect(repository.trashNotes.single.id, note.id);

    repository.restore(note);
    expect(repository.activeNotes.single.id, note.id);
  });

  test('orders pinned notes first', () {
    final repository = NoteRepository();
    final first = repository.createNote();
    final second = repository.createNote();
    repository.togglePinned(second);

    expect(repository.activeNotes.first.id, second.id);
    expect(repository.activeNotes.last.id, first.id);
  });
}
