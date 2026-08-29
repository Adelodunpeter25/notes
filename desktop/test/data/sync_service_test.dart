import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_server.dart';
import '../helpers/test_core.dart';
import 'package:desktop/data/api/api_service.dart';
import 'package:desktop/data/sync/sync_service.dart';

void main() {
  late TestCore core;
  late MockServerAdapter server;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core = await TestCore.create();
    server = MockServerAdapter({});
    final dio = Dio(BaseOptions(baseUrl: 'https://mock.local/api/'))
      ..httpClientAdapter = server;
    syncService = SyncService(core.db, ApiService(dio: dio), core.syncOpDao);
  });

  tearDown(() async {
    await core.dispose();
  });

  test('pushes queued ops FIFO, then clears acked ops and stores the cursor',
      () async {
    final note = await core.noteService.createNote(
      title: 'Local Note',
      content: 'local content',
      userId: TestCore.testUserId,
    );
    await core.noteService.pinNote(note, true);

    server.routes['sync'] = (req) async {
      final body = req.body as Map<String, dynamic>;
      final ops = (body['ops'] as List).cast<Map>();
      return MockServerAdapter.jsonResponse(200, {
        'nextCursor': 'cursor-2',
        'processedOpIds': ops.map((op) => op['id']).toList(),
        'notes': [],
        'folders': [],
        'deleted': [],
      });
    };

    await syncService.syncData(TestCore.testUserId);

    // Request contract: {cursor: null (first sync), ops: [...]}
    final request = server.requests.single;
    expect(request.path, endsWith('/sync'));
    final sentBody = request.body as Map<String, dynamic>;
    expect(sentBody['cursor'], isNull);
    final sentOps = (sentBody['ops'] as List).cast<Map>();
    expect(sentOps, hasLength(2));
    expect(sentOps.first['type'], 'upsert');
    expect(sentOps.first['entityType'], 'note');
    expect((sentOps.first['payload'] as Map)['title'], 'Local Note');

    // Acked ops removed from the queue.
    expect(await syncService.pendingOpCount(), 0);

    // Cursor persisted for the next round trip.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sync_cursor'), 'cursor-2');
  });

  test('applies pulled notes and folders (folders first, FTS updated)',
      () async {
    final remoteDoc = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'delta': [
              {'insert': 'From my phone'},
            ],
          },
        ],
      },
    });

    server.routes['sync'] = (req) async => MockServerAdapter.jsonResponse(200, {
          'nextCursor': 'cursor-3',
          'processedOpIds': [],
          'folders': [
            {
              'id': 'folder-remote-1',
              'name': 'From Phone',
              'userId': TestCore.testUserId,
              'deletedAt': null,
            }
          ],
          'notes': [
            {
              'id': 'note-remote-1',
              'title': 'From my phone',
              'content': remoteDoc,
              'userId': TestCore.testUserId,
              'folderId': 'folder-remote-1',
              'isPinned': true,
              'createdAt': '2026-01-01T10:00:00.000Z',
              'updatedAt': '2026-01-01T10:00:00.000Z',
              'deletedAt': null,
            }
          ],
          'deleted': [],
        });

    await syncService.syncData(TestCore.testUserId);

    final note = await (core.db.select(core.db.notes)
          ..where((t) => t.id.equals('note-remote-1')))
        .getSingle();
    expect(note.title, 'From my phone');
    expect(note.isPinned, isTrue);
    expect(note.folderId, 'folder-remote-1');

    // Pulled note is searchable — FTS index updated on apply.
    expect(await core.noteService.searchNotes(TestCore.testUserId, 'phone'),
        hasLength(1));
  });

  test('applies note tombstones: soft-deletes locally and removes from FTS',
      () async {
    final note = await core.noteService.createNote(
      title: 'Doomed',
      content: 'zebra crossing',
      userId: TestCore.testUserId,
    );

    server.routes['sync'] = (req) async => MockServerAdapter.jsonResponse(200, {
          'nextCursor': 'cursor-4',
          'processedOpIds': [],
          'notes': [],
          'folders': [],
          'deleted': [
            {
              'entityId': note.id,
              'entityType': 'note',
              'deletedAt': '2026-01-02T10:00:00.000Z',
            }
          ],
        });

    await syncService.syncData(TestCore.testUserId);

    expect(await core.noteDao.watchAllNotes(TestCore.testUserId).first,
        isEmpty);
    expect(await core.noteDao.watchTrashNotes(TestCore.testUserId).first,
        hasLength(1));
    expect(
        await core.noteService.searchNotes(TestCore.testUserId, 'zebra'),
        isEmpty);
  });

  test('applies folder tombstones: clears folder refs and removes the folder',
      () async {
    final folder =
        await core.folderService.createFolder('Soon Gone', TestCore.testUserId);
    final note = await core.noteService.createNote(
      title: 'Orphan Candidate',
      content: 'x',
      userId: TestCore.testUserId,
    );
    await core.noteService.moveNoteToFolder(note, folder.id);

    server.routes['sync'] = (req) async => MockServerAdapter.jsonResponse(200, {
          'nextCursor': 'cursor-5',
          'processedOpIds': [],
          'notes': [],
          'folders': [],
          'deleted': [
            {
              'entityId': folder.id,
              'entityType': 'folder',
              'deletedAt': '2026-01-02T10:00:00.000Z',
            }
          ],
        });

    await syncService.syncData(TestCore.testUserId);

    final notes = await core.noteDao.watchAllNotes(TestCore.testUserId).first;
    expect(notes, hasLength(1));
    expect(notes.first.folderId, isNull);

    final folders = await core.db.select(core.db.folders).get();
    expect(folders, isEmpty);
  });

  test('failed sync keeps ops queued and preserves the cursor', () async {
    await core.noteService.createNote(
      title: 'Queued',
      content: 'y',
      userId: TestCore.testUserId,
    );

    // Simulate a server outage.
    server.routes['sync'] =
        (req) async => MockServerAdapter.jsonResponse(500, {'error': 'boom'});

    await syncService.syncData(TestCore.testUserId);

    expect(await syncService.pendingOpCount(), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sync_cursor'), isNull);
  });

  test('re-sync uses the stored cursor', () async {
    server.routes['sync'] = (req) async => MockServerAdapter.jsonResponse(200, {
          'nextCursor': 'cursor-6',
          'processedOpIds': [],
          'notes': [],
          'folders': [],
          'deleted': [],
        });

    await syncService.syncData(TestCore.testUserId);
    await syncService.syncData(TestCore.testUserId);

    final last = server.requests.last;
    expect((last.body as Map<String, dynamic>)['cursor'], 'cursor-6');
  });
}
