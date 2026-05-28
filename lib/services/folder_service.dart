import '../database/database.dart';
import '../database/daos.dart';

class FolderService {
  final FolderDao folderDao;

  FolderService(this.folderDao);

  Stream<List<FolderWithCount>> watchFolders(int userId) {
    return folderDao.watchFoldersWithNoteCount(userId);
  }

  Future<int> createFolder(String name, int userId) {
    return folderDao.insertFolder(
      FoldersCompanion.insert(name: name, userId: userId),
    );
  }

  Future deleteFolder(Folder folder) {
    return folderDao.deleteFolder(folder);
  }
}
