import 'dart:developer' as dev;
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import 'api_service.dart';

class SyncService {
  final AppDatabase db;
  final ApiService api;
  static const String _cursorKey = 'sync_cursor';

  SyncService(this.db, this.api);

  /// Synchronizes local database with remote database using sync-force or sync cursor.
  Future<void> syncData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cursor = prefs.getString(_cursorKey);

    try {
      final response = await api.post('/sync', {
        'cursor': cursor,
        'ops': [],
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final nextCursor = data['nextCursor'] as String;
        final notesList = data['notes'] as List<dynamic>;
        final foldersList = data['folders'] as List<dynamic>;
        final deletedList = data['deleted'] as List<dynamic>;

        // Store folders in database
        for (final f in foldersList) {
          await db.into(db.folders).insertOnConflictUpdate(
            FoldersCompanion.insert(
              id: f['id'] as String,
              name: f['name'] as String,
              userId: f['userId'] as String,
              deletedAt: f['deletedAt'] != null 
                  ? Value(DateTime.parse(f['deletedAt'] as String)) 
                  : const Value(null),
            ),
          );
        }

        // Store notes in database
        for (final n in notesList) {
          await db.into(db.notes).insertOnConflictUpdate(
            NotesCompanion.insert(
              id: n['id'] as String,
              title: n['title'] as String,
              content: n['content'] as String,
              userId: n['userId'] as String,
              folderId: Value(n['folderId'] as String?),
              isPinned: Value(n['isPinned'] as bool? ?? false),
              createdAt: n['createdAt'] != null
                  ? Value(DateTime.parse(n['createdAt'] as String))
                  : Value(DateTime.now()),
              updatedAt: n['updatedAt'] != null
                  ? Value(DateTime.parse(n['updatedAt'] as String))
                  : Value(DateTime.now()),
              deletedAt: n['deletedAt'] != null
                  ? Value(DateTime.parse(n['deletedAt'] as String))
                  : const Value(null),
            ),
          );
        }

        // Process deleted tombstones
        for (final d in deletedList) {
          final entityId = d['entityId'] as String;
          final entityType = d['entityType'] as String;
          final deletedAtVal = DateTime.parse(d['deletedAt'] as String);

          if (entityType == 'note') {
            await (db.update(db.notes)..where((t) => t.id.equals(entityId))).write(
              NotesCompanion(deletedAt: Value(deletedAtVal)),
            );
          } else if (entityType == 'folder') {
            await (db.update(db.folders)..where((t) => t.id.equals(entityId))).write(
              FoldersCompanion(deletedAt: Value(deletedAtVal)),
            );
          }
        }

        // Save new cursor
        await prefs.setString(_cursorKey, nextCursor);
      }
    } catch (e, stackTrace) {
      dev.log('Sync error', error: e, stackTrace: stackTrace);
    }
  }
}
