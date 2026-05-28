import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/daos.dart';

class FolderService {
  final FolderDao folderDao;
  final _uuid = const Uuid();

  FolderService(this.folderDao);

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

  Future deleteFolder(Folder folder) {
    return folderDao.deleteFolder(folder);
  }
}
