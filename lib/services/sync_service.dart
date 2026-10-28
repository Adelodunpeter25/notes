import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart' show DioException, Response;
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/daos.dart';
import '../utils/note.dart';
import 'api_service.dart';

/// Thrown by [SyncService.syncData] when the server answers 401: the stored
/// token is expired or was signed with a rotated secret.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Your session has expired. Please sign in again.';
}

class SyncService {
  final AppDatabase db;
  final ApiService api;
  final SyncOpDao _opDao;
  static const String _cursorKey = 'sync_cursor';
  static const String _cursorScopeKey = 'sync_cursor_scope';

  SyncService(this.db, this.api, this._opDao);

  /// Pushes queued local mutations to the server, then pulls remote changes.
  ///
  /// Op shape matches server/types/sync.ts:
  ///   {id, type: 'upsert'|'delete', entityType, entityId, updatedAt, payload}
  /// Server replies with:
  ///   {nextCursor, notes, folders, deleted, processedOpIds, errors?}
  Future<void> syncData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    // A cursor only means something to the server (and user) that issued it.
    // After moving servers, or switching accounts, the old cursor would hide
    // every row older than it, so fall back to a full pull instead.
    final scope = '$userId@${ApiService.baseUrl}';
    final cursor = prefs.getString(_cursorScopeKey) == scope
        ? prefs.getString(_cursorKey)
        : null;

    // 1. Drain pending ops FIFO. Only the newest op per entity matters
    //    (every op carries the full row), so collapse the rest — they are
    //    acked locally once the surviving op is accepted.
    final pending = await _opDao.pullPending();
    final latest = <String, SyncOp>{};
    final superseded = <String>[];
    for (final op in pending) {
      final key = '${op.entityType}:${op.entityId}';
      final prev = latest[key];
      if (prev != null) superseded.add(prev.id);
      latest[key] = op;
    }
    if (superseded.isNotEmpty) await _opDao.deleteOps(superseded);

    final ops = latest.values
        .map((op) => {
              'id': op.id,
              'type': op.opType,
              'entityType': op.entityType,
              'entityId': op.entityId,
              'updatedAt': op.updatedAt.toIso8601String(),
              'payload': jsonDecode(op.payload),
            })
        .toList();

    try {
      // Push in small batches so one request never exceeds the server's
      // body limit; the last response also carries the pull data.
      const batchSize = 100;
      Response? response;
      var i = 0;
      do {
        final chunk = ops.sublist(i, (i + batchSize).clamp(0, ops.length));
        response = await api.post('sync', {
          'cursor': cursor,
          'ops': chunk,
        });
        if (response.statusCode == 401) throw SessionExpiredException();
        if (response.statusCode != 200) {
          dev.log('Sync failed: ${response.statusCode} ${response.data}');
          return;
        }
        final acked = ((response.data as Map?)?['processedOpIds'] as List? ?? const [])
            .whereType<String>()
            .toList();
        if (acked.isNotEmpty) await _opDao.deleteOps(acked);
        i += batchSize;
      } while (i < ops.length);

      final data = response.data as Map<String, dynamic>? ?? {};

      // 2. Server tells us which ops it applied — only clear those.
      final processedIds = (data['processedOpIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (processedIds.isNotEmpty) {
        await _opDao.deleteOps(processedIds);
      }

      final errors = data['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        dev.log('Sync: ${errors.length} ops rejected by server: $errors');
      }

      // 3. Persist the new cursor.
      final nextCursor = data['nextCursor'] as String?;
      if (nextCursor != null) {
        await prefs.setString(_cursorKey, nextCursor);
        await prefs.setString(_cursorScopeKey, scope);
      }

      // 4. Apply pulled data (folders first so FKs exist for notes).
      final foldersList = data['folders'] as List<dynamic>? ?? const [];
      for (final f in foldersList) {
        if (f is! Map) continue;
        final m = Map<String, dynamic>.from(f);
        final id = m['id'] as String?;
        final name = m['name'] as String?;
        final uid = m['userId'] as String?;
        if (id == null || name == null || uid == null) continue;
        await db.into(db.folders).insertOnConflictUpdate(
          FoldersCompanion.insert(
            id: id,
            name: name,
            userId: uid,
            deletedAt: Value(_parseDate(m['deletedAt'])),
          ),
        );
      }

      final notesList = data['notes'] as List<dynamic>? ?? const [];
      for (final n in notesList) {
        if (n is! Map) continue;
        final m = Map<String, dynamic>.from(n);
        final id = m['id'] as String?;
        final title = m['title'] as String? ?? '';
        final content = m['content'] as String? ?? '';
        final uid = m['userId'] as String?;
        if (id == null || uid == null) continue;
        await db.into(db.notes).insertOnConflictUpdate(
          NotesCompanion.insert(
            id: id,
            title: title,
            content: content,
            userId: uid,
            folderId: Value(m['folderId'] as String?),
            isPinned: Value(_coerceBool(m['isPinned'])),
            createdAt: Value(_parseDate(m['createdAt']) ?? DateTime.now()),
            updatedAt: Value(_parseDate(m['updatedAt']) ?? DateTime.now()),
            deletedAt: Value(_parseDate(m['deletedAt'])),
          ),
        );
        final plainContent = NoteUtils.extractLines(content).join(' ');
        await db.upsertNoteFts(id, title, plainContent, uid);
      }

      // 5. Apply tombstones.
      final deletedList = data['deleted'] as List<dynamic>? ?? const [];
      for (final d in deletedList) {
        if (d is! Map) continue;
        final m = Map<String, dynamic>.from(d);
        final entityId = m['entityId'] as String?;
        final entityType = m['entityType'] as String?;
        final deletedAt = _parseDate(m['deletedAt']);
        if (entityId == null || entityType == null || deletedAt == null) continue;

        if (entityType == 'note') {
          await (db.update(db.notes)..where((t) => t.id.equals(entityId))).write(
            NotesCompanion(deletedAt: Value(deletedAt)),
          );
          await db.deleteNoteFts(entityId);
        } else if (entityType == 'folder') {
          await (db.update(db.notes)..where((t) => t.folderId.equals(entityId))).write(
            const NotesCompanion(folderId: Value(null)),
          );
          await (db.delete(db.folders)..where((t) => t.id.equals(entityId))).go();
        }
      }
    } on SessionExpiredException {
      rethrow;
    } on DioException catch (e, stackTrace) {
      if (e.response?.statusCode == 401) throw SessionExpiredException();
      dev.log('Sync error', error: e, stackTrace: stackTrace);
      // Ops stay queued for the next attempt — we didn't ack them.
    } catch (e, stackTrace) {
      dev.log('Sync error', error: e, stackTrace: stackTrace);
      // Ops stay queued for the next attempt — we didn't ack them.
    }
  }

  /// How many local mutations are waiting to be pushed.
  Future<int> pendingOpCount() => _opDao.countPending();

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _coerceBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}
