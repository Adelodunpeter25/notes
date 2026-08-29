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

  test('createFolder persists a folder and records a sync op', () async {
    final folder = await core.folderService.createFolder(
      'Work',
      TestCore.testUserId,
    );

    expect(folder.name, 'Work');
    expect(folder.userId, TestCore.testUserId);
    expect(folder.id, hasLength(36));

    final folders =
        await core.folderDao.watchFoldersWithNoteCount(TestCore.testUserId).first;
    expect(folders, hasLength(1));
    expect(folders.first.folder.id, folder.id);
    expect(folders.first.noteCount, 0);

    final ops = await core.syncOpDao.pullPending();
    expect(ops.last.entityType, 'folder');
    expect(ops.last.opType, 'upsert');
  });

  test('moveNoteToFolder moves a note and it shows in the folder stream',
      () async {
    final folder =
        await core.folderService.createFolder('Work', TestCore.testUserId);
    final note = await core.noteService.createNote(
      title: 'Work Note',
      content: 'Work content',
      userId: TestCore.testUserId,
    );

    expect(note.folderId, isNull);

    await core.noteService.moveNoteToFolder(note, folder.id);

    final inFolder = await core.noteDao
        .watchNotesInFolder(TestCore.testUserId, folder.id)
        .first;
    expect(inFolder, hasLength(1));
    expect(inFolder.first.id, note.id);
    expect(inFolder.first.folderId, folder.id);

    final counts = await core.noteDao
        .watchPerFolderCounts(TestCore.testUserId)
        .first;
    expect(counts[folder.id], 1);
  });

  test('deleteFolder unassigns its notes and records a hard delete',
      () async {
    final folder =
        await core.folderService.createFolder('Work', TestCore.testUserId);
    final note = await core.noteService.createNote(
      title: 'Work Note',
      content: 'Work content',
      userId: TestCore.testUserId,
    );
    await core.noteService.moveNoteToFolder(note, folder.id);

    await core.folderService.deleteFolder(folder);

    // Note survives, back at root.
    final rootNotes =
        await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(rootNotes, hasLength(1));
    expect(rootNotes.first.folderId, isNull);

    // Folder row is gone.
    expect(
      await core.folderDao.watchFoldersWithNoteCount(TestCore.testUserId).first,
      isEmpty,
    );

    final ops = await core.syncOpDao.pullPending();
    expect(
      ops.where(
        (op) => op.opType == 'delete' && op.entityType == 'folder',
      ),
      hasLength(1),
    );
  });

  test('renameFolder persists the new name', () async {
    final folder =
        await core.folderService.createFolder('Old', TestCore.testUserId);

    await core.folderService.renameFolder(folder, 'New');

    final folders =
        await core.folderDao.watchFoldersWithNoteCount(TestCore.testUserId).first;
    expect(folders.first.folder.name, 'New');
  });
}
