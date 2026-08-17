import Foundation

public final class NoteService {
    private let storage: StorageService
    private let recorder: SyncOpRecorder
    private let searchService: SearchService
    
    public init(storage: StorageService, recorder: SyncOpRecorder, searchService: SearchService) {
        self.storage = storage
        self.recorder = recorder
        self.searchService = searchService
    }
    
    public func searchNotes(query: String, userId: String) -> [DBNote] {
        return searchService.searchNotes(query: query, userId: userId)
    }
    
    public func createNote(title: String, content: String, userId: String, folderId: String? = nil) -> DBNote? {
        let noteId = UUID().uuidString.lowercased()
        let now = Date()
        let note = DBNote(
            id: noteId,
            title: title,
            content: content,
            createdAt: now,
            updatedAt: now,
            isPinned: false,
            folderId: folderId,
            userId: userId
        )
        
        guard storage.insertNote(note) else { return nil }
        _ = recorder.noteCreated(note)
        return note
    }
    
    public func updateNote(_ note: DBNote) -> Bool {
        var updated = note
        updated.updatedAt = Date()
        guard storage.updateNote(updated) else { return false }
        _ = recorder.noteUpdated(updated)
        return true
    }
    
    public func pinNote(_ note: DBNote, isPinned: Bool) -> Bool {
        var updated = note
        updated.isPinned = isPinned
        updated.updatedAt = Date()
        guard storage.updateNote(updated) else { return false }
        _ = recorder.notePinned(updated)
        return true
    }
    
    public func softDeleteNote(_ note: DBNote) -> Bool {
        var updated = note
        updated.deletedAt = Date()
        updated.updatedAt = Date()
        guard storage.updateNote(updated) else { return false }
        _ = recorder.noteSoftDeleted(updated)
        return true
    }
    
    public func restoreNote(_ note: DBNote) -> Bool {
        var updated = note
        updated.deletedAt = nil
        updated.updatedAt = Date()
        guard storage.updateNote(updated) else { return false }
        _ = recorder.noteRestored(updated)
        return true
    }
    
    public func moveNoteToFolder(_ note: DBNote, folderId: String?) -> Bool {
        var updated = note
        updated.folderId = folderId
        updated.updatedAt = Date()
        guard storage.updateNote(updated) else { return false }
        _ = recorder.noteMoved(updated)
        return true
    }
    
    public func emptyTrash(userId: String) -> Bool {
        let trashNotes = storage.listTrashNotes(userId: userId)
        let ids = trashNotes.map { $0.id }
        
        guard storage.emptyTrash(userId: userId) else { return false }
        if !ids.isEmpty {
            _ = recorder.noteHardDeletedIds(ids: ids, userId: userId)
        }
        return true
    }
    
    public func deleteNotePermanently(_ note: DBNote) -> Bool {
        guard storage.deleteNotePermanently(id: note.id) else { return false }
        _ = recorder.noteHardDeleted(note)
        return true
    }
    
    public func autoDeleteEmptyNotes(userId: String) {
        let activeNotes = storage.listActiveNotes(userId: userId)
        for note in activeNotes {
            if NoteUtils.isNoteEmpty(title: note.title, content: note.content) {
                _ = storage.deleteNotePermanently(id: note.id)
                _ = recorder.noteHardDeleted(note)
            }
        }
    }
}
