import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';
import 'note_service.dart';

class FolderService {
  final FolderDao folderDao;
  final NoteService noteService;
  final _uuid = const Uuid();

  FolderService(this.folderDao, this.noteService);

  Stream<List<FolderWithCount>> watchFolders(String userId) {
    return folderDao.watchFoldersWithNoteCount(userId);
  }

  Future<int> createFolder(String name, String userId) {
    return folderDao.insertFolder(
      FoldersCompanion.insert(
        id: _uuid.v4(),
        name: name,
        userId: userId,
      ),
    );
  }

  Future renameFolder(Folder folder, String newName) {
    return folderDao.updateFolder(folder.copyWith(name: newName));
  }

  Future softDeleteFolder(Folder folder) async {
    // Move child notes back to root first, otherwise they'd be invisible
    // (still referencing a folder that's now marked deleted).
    await noteService.clearFolderFromNotes(folder.id);
    return folderDao.updateFolder(folder.copyWith(deletedAt: Value(DateTime.now())));
  }

  Future restoreFolder(Folder folder) {
    return folderDao.updateFolder(folder.copyWith(deletedAt: const Value(null)));
  }
}
