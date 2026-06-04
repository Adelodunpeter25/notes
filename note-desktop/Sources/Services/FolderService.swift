import Foundation

public final class FolderService {
    private let storage: StorageService
    private let noteService: NoteService
    private let recorder: SyncOpRecorder
    
    public init(storage: StorageService, noteService: NoteService, recorder: SyncOpRecorder) {
        self.storage = storage
        self.noteService = noteService
        self.recorder = recorder
    }
    
    public func createFolder(name: String, userId: String) -> DBFolder? {
        let folderId = UUID().uuidString
        let folder = DBFolder(id: folderId, name: name, userId: userId)
        
        guard storage.insertFolder(folder) else { return nil }
        _ = recorder.folderCreated(folder)
        return folder
    }
    
    public func renameFolder(_ folder: DBFolder, newName: String) -> Bool {
        var updated = folder
        updated.name = newName
        guard storage.updateFolder(updated) else { return false }
        _ = recorder.folderRenamed(updated)
        return true
    }
    
    public func deleteFolder(_ folder: DBFolder) -> Bool {
        // Move child notes back to root first
        _ = storage.clearFolderFromNotes(folderId: folder.id)
        guard storage.deleteFolder(id: folder.id) else { return false }
        _ = recorder.folderHardDeleted(folder)
        return true
    }
}
