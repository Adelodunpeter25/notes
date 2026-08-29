import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';

/// Thin wrapper around [SyncOpDao] that services use to record local
/// mutations. Each op is written with a client-generated UUID id and an
/// updatedAt timestamp — the server uses both for idempotency and conflict
/// resolution (see server/services/sync.ts processUpsert).
class SyncOpRecorder {
  final SyncOpDao _dao;
  final _uuid = const Uuid();

  SyncOpRecorder(this._dao);

  // ---------- Notes ----------
  Future<void> noteCreated(Note n) => _upsertNote(n);
  Future<void> noteUpdated(Note n) => _upsertNote(n);
  Future<void> noteSoftDeleted(Note n) => _upsertNote(n);
  Future<void> noteRestored(Note n) => _upsertNote(n);
  Future<void> notePinned(Note n) => _upsertNote(n);
  Future<void> noteMoved(Note n) => _upsertNote(n);
  Future<void> noteHardDeleted(Note n) =>
      _record('delete', 'note', n.id, _notePayload(n), n.updatedAt);

  /// Record one hard-delete op per trashed note id. Used after emptyTrash
  /// wipes the local rows so the server also hard-deletes.
  Future<void> noteHardDeletedIds(List<String> ids, String userId) async {
    final now = DateTime.now();
    for (final id in ids) {
      await _record(
        'delete',
        'note',
        id,
        jsonEncode({'id': id, 'userId': userId, 'hard': true}),
        now,
      );
    }
  }

  Future<void> _upsertNote(Note n) =>
      _record('upsert', 'note', n.id, _notePayload(n), n.updatedAt);

  // ---------- Folders ----------
  Future<void> folderCreated(Folder f) => _upsertFolder(f);
  Future<void> folderRenamed(Folder f) => _upsertFolder(f);
  Future<void> folderSoftDeleted(Folder f) => _upsertFolder(f);
  Future<void> folderRestored(Folder f) => _upsertFolder(f);
  Future<void> folderHardDeleted(Folder f) => _record(
      'delete', 'folder', f.id,
      jsonEncode({'id': f.id, 'userId': f.userId, 'hard': true}),
      DateTime.now());

  Future<void> _upsertFolder(Folder f) =>
      _record('upsert', 'folder', f.id, _folderPayload(f), DateTime.now());

  // ---------- Helpers ----------
  Future<void> _record(
    String opType,
    String entityType,
    String entityId,
    String payload,
    DateTime updatedAt,
  ) {
    return _dao.insertOp(
      id: _uuid.v4(),
      opType: opType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      updatedAt: updatedAt,
    );
  }

  String _notePayload(Note n) {
    return jsonEncode({
      'id': n.id,
      'title': n.title,
      'content': n.content,
      'createdAt': n.createdAt.toIso8601String(),
      'updatedAt': n.updatedAt.toIso8601String(),
      'isPinned': n.isPinned,
      'folderId': n.folderId,
      'userId': n.userId,
      'deletedAt': n.deletedAt?.toIso8601String(),
    });
  }

  String _folderPayload(Folder f) {
    return jsonEncode({
      'id': f.id,
      'name': f.name,
      'userId': f.userId,
      'deletedAt': f.deletedAt?.toIso8601String(),
    });
  }
}
