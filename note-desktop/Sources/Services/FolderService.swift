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
    
    public func softDeleteFolder(_ folder: DBFolder) -> Bool {
        // Move child notes back to root first, otherwise they'd be invisible
        _ = storage.clearFolderFromNotes(folderId: folder.id)
        
        var updated = folder
        updated.deletedAt = Date()
        guard storage.updateFolder(updated) else { return false }
        _ = recorder.folderSoftDeleted(updated)
        return true
    }
    
    public func restoreFolder(_ folder: DBFolder) -> Bool {
        var updated = folder
        updated.deletedAt = nil
        guard storage.updateFolder(updated) else { return false }
        _ = recorder.folderRestored(updated)
        return true
    }
}
