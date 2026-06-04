import 'dart:convert';
import '../database/database.dart';
import '../database/daos.dart';

/// Thin wrapper around [SyncOpDao] passed to services that need to record
/// local mutations. Services don't talk to the sync service directly — they
/// just drop an op in the queue and let the next sync drain it.
class SyncOpRecorder {
  final SyncOpDao _dao;
  SyncOpRecorder(this._dao);

  Future<void> noteCreated(Note n) => _record('create', 'note', n.id, _notePayload(n));
  Future<void> noteUpdated(Note n) => _record('update', 'note', n.id, _notePayload(n));
  Future<void> noteSoftDeleted(Note n) => _record('update', 'note', n.id, _notePayload(n));
  Future<void> noteRestored(Note n) => _record('update', 'note', n.id, _notePayload(n));
  Future<void> notePinned(Note n) => _record('update', 'note', n.id, _notePayload(n));
  Future<void> noteMoved(Note n) => _record('update', 'note', n.id, _notePayload(n));
  Future<void> noteHardDeleted(Note n) => _record('delete', 'note', n.id, _notePayload(n));
  Future<void> noteEmptyTrash(String userId) =>
      _record('empty_trash', 'note', userId, jsonEncode({'userId': userId}));

  Future<void> folderCreated(Folder f) => _record('create', 'folder', f.id, _folderPayload(f));
  Future<void> folderRenamed(Folder f) => _record('update', 'folder', f.id, _folderPayload(f));
  Future<void> folderSoftDeleted(Folder f) => _record('update', 'folder', f.id, _folderPayload(f));
  Future<void> folderRestored(Folder f) => _record('update', 'folder', f.id, _folderPayload(f));
  Future<void> folderEmptyTrash(String userId) =>
      _record('empty_trash', 'folder', userId, jsonEncode({'userId': userId}));

  Future<void> _record(String opType, String entityType, String entityId, String payload) {
    return _dao.insertOp(
      opType: opType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
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
