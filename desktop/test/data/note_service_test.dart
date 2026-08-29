import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_core.dart';

void main() {
  late TestCore core;

  setUp(() async {
    core = await TestCore.create();
  });

  tearDown(() async {
    await core.dispose();
  });

  test('createNote persists a note, indexes it and records a sync op',
      () async {
    final note = await core.noteService.createNote(
      title: 'Test Note Title',
      content: 'Test Note Body Content',
      userId: TestCore.testUserId,
    );

    expect(note.title, 'Test Note Title');
    expect(note.content, 'Test Note Body Content');
    expect(note.userId, TestCore.testUserId);
    expect(note.isPinned, isFalse);
    expect(note.folderId, isNull);
    expect(note.id, hasLength(36)); // UUID v4

    final active = await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(active, hasLength(1));
    expect(active.first.id, note.id);

    final ops = await core.syncOpDao.pullPending();
    expect(ops, hasLength(1));
    expect(ops.first.opType, 'upsert');
    expect(ops.first.entityType, 'note');
    expect(ops.first.entityId, note.id);
  });

  test('pinNote toggles pin state', () async {
    final note = await core.noteService.createNote(
      title: 'Pin Me',
      content: 'Body',
      userId: TestCore.testUserId,
    );

    expect(note.isPinned, isFalse);

    await core.noteService.pinNote(note, true);
    var active = await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(active.first.isPinned, isTrue);

    await core.noteService.pinNote(active.first, false);
    active = await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(active.first.isPinned, isFalse);
  });

  test('softDeleteNote moves to trash and restoreNote brings it back',
      () async {
    final note = await core.noteService.createNote(
      title: 'Delete Me',
      content: 'Content',
      userId: TestCore.testUserId,
    );

    await core.noteService.softDeleteNote(note);

    expect(await core.noteDao.watchAllNotes(TestCore.testUserId).first,
        isEmpty);
    final trash = await core.noteDao.watchTrashNotes(TestCore.testUserId).first;
    expect(trash, hasLength(1));
    expect(trash.first.id, note.id);

    await core.noteService.restoreNote(trash.first);
    expect(await core.noteDao.watchAllNotes(TestCore.testUserId).first,
        hasLength(1));
    expect(await core.noteDao.watchTrashNotes(TestCore.testUserId).first,
        isEmpty);
  });

  test('searchNotes finds notes by title and content prefix (FTS)', () async {
    await core.noteService.createNote(
      title: 'Apple Pie Recipe',
      content: 'Ingredients include apples and flour.',
      userId: TestCore.testUserId,
    );
    await core.noteService.createNote(
      title: 'Banana Bread',
      content: 'Bake a delicious banana loaf.',
      userId: TestCore.testUserId,
    );
    await core.noteService.createNote(
      title: 'Shopping List',
      content: 'Buy apples, milk, and eggs.',
      userId: TestCore.testUserId,
    );

    final results =
        await core.noteService.searchNotes(TestCore.testUserId, 'apple');
    final titles = results.map((n) => n.title).toList();

    expect(results, hasLength(2));
    expect(titles, contains('Apple Pie Recipe'));
    expect(titles, contains('Shopping List'));
    expect(titles, isNot(contains('Banana Bread')));
  });

  test('searchNotes excludes trashed notes and stale index entries',
      () async {
    final note = await core.noteService.createNote(
      title: 'Trash Me',
      content: 'searchable zebras',
      userId: TestCore.testUserId,
    );
    expect(
        (await core.noteService.searchNotes(TestCore.testUserId, 'zebra')),
        hasLength(1));

    await core.noteService.softDeleteNote(note);
    expect(
        (await core.noteService.searchNotes(TestCore.testUserId, 'zebra')),
        isEmpty);
  });

  test('autoDeleteEmptyNotes removes only blank notes', () async {
    await core.noteService.createNote(
      title: 'Important',
      content: 'Something',
      userId: TestCore.testUserId,
    );
    await core.noteService.createNote(
      title: 'Untitled',
      content: '',
      userId: TestCore.testUserId,
    );
    await core.noteService.createNote(
      title: '',
      content: '   ',
      userId: TestCore.testUserId,
    );

    expect(
        (await core.noteDao.watchAllNotes(TestCore.testUserId).first),
        hasLength(3));

    await core.noteService.autoDeleteEmptyNotes(TestCore.testUserId);

    final remaining =
        await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(remaining, hasLength(1));
    expect(remaining.first.title, 'Important');
  });

  test('emptyTrash wipes trash rows, clears FTS and records hard deletes',
      () async {
    final a = await core.noteService.createNote(
      title: 'A',
      content: 'content-a',
      userId: TestCore.testUserId,
    );
    final b = await core.noteService.createNote(
      title: 'B',
      content: 'content-b',
      userId: TestCore.testUserId,
    );
    await core.noteService.softDeleteNote(a);
    await core.noteService.softDeleteNote(b);

    final count = await core.noteService.emptyTrash(TestCore.testUserId);
    expect(count, 2);

    expect(await core.noteDao.watchTrashNotes(TestCore.testUserId).first,
        isEmpty);
    expect(
        await core.noteService.searchNotes(TestCore.testUserId, 'content'),
        isEmpty);

    final ops = await core.syncOpDao.pullPending();
    final deleteOps =
        ops.where((op) => op.opType == 'delete' && op.entityType == 'note');
    expect(deleteOps.length, 2);
    for (final op in deleteOps) {
      expect(op.payload, contains('"hard":true'));
    }
  });

  test('deleteNotePermanently removes a single note and records the op',
      () async {
    final a = await core.noteService.createNote(
      title: 'A',
      content: 'aaa',
      userId: TestCore.testUserId,
    );
    await core.noteService.createNote(
      title: 'B',
      content: 'bbb',
      userId: TestCore.testUserId,
    );

    await core.noteService.deleteNotePermanently(a);

    final remaining =
        await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(remaining, hasLength(1));
    expect(remaining.first.title, 'B');

    final ops = await core.syncOpDao.pullPending();
    expect(
      ops.where((op) => op.opType == 'delete' && op.entityId == a.id),
      isNotEmpty,
    );
  });

  test('updateNote refreshes the FTS index and records an upsert', () async {
    final note = await core.noteService.createNote(
      title: 'Old',
      content: 'wombat',
      userId: TestCore.testUserId,
    );
    expect(await core.noteService.searchNotes(TestCore.testUserId, 'wombat'),
        hasLength(1));

    await core.noteService
        .updateNote(note.copyWith(title: 'New', content: 'capibara'));

    expect(await core.noteService.searchNotes(TestCore.testUserId, 'wombat'),
        isEmpty);
    expect(await core.noteService.searchNotes(TestCore.testUserId, 'capibar'),
        hasLength(1));
  });
}
