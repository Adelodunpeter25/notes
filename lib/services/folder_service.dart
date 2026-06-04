import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';
import 'note_service.dart';
import 'sync_op_recorder.dart';

class FolderService {
  final FolderDao folderDao;
  final NoteService noteService;
  final SyncOpRecorder _recorder;
  final _uuid = const Uuid();

  FolderService(this.folderDao, this.noteService, this._recorder);

  Stream<List<FolderWithCount>> watchFolders(String userId) {
    return folderDao.watchFoldersWithNoteCount(userId);
  }

  Future<int> createFolder(String name, String userId) async {
    final id = _uuid.v4();
    final folder = Folder(id: id, name: name, userId: userId);
    final rowId = await folderDao.insertFolder(
      FoldersCompanion.insert(
        id: id,
        name: name,
        userId: userId,
      ),
    );
    await _recorder.folderCreated(folder);
    return rowId;
  }

  Future renameFolder(Folder folder, String newName) async {
    final updated = folder.copyWith(name: newName);
    await folderDao.updateFolder(updated);
    await _recorder.folderRenamed(updated);
  }

  Future deleteFolder(Folder folder) async {
    // Move child notes back to root first, otherwise they'd be invisible
    await noteService.clearFolderFromNotes(folder.id);
    await folderDao.deleteFolder(folder);
    await _recorder.folderHardDeleted(folder);
  }
}
