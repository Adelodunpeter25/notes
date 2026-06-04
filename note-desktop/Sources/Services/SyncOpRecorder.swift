import Foundation

public final class SyncOpRecorder {
    private let storage: StorageService
    
    public init(storage: StorageService) {
        self.storage = storage
    }
    
    // MARK: - Notes
    
    public func noteCreated(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteUpdated(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteSoftDeleted(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteRestored(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func notePinned(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteMoved(_ note: DBNote) -> Bool {
        return record(opType: "upsert", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteHardDeleted(_ note: DBNote) -> Bool {
        return record(opType: "delete", entityType: "note", entityId: note.id, payload: try? JSONEncoder().encode(note), updatedAt: note.updatedAt)
    }
    
    public func noteHardDeletedIds(ids: [String], userId: String) -> Bool {
        let now = Date()
        var success = true
        for id in ids {
            let payloadDict: [String: Any] = ["id": id, "userId": userId, "hard": true]
            guard let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict, options: []),
                  let payloadStr = String(data: payloadData, encoding: .utf8) else {
                success = false
                continue
            }
            let op = DBSyncOp(id: UUID().uuidString, opType: "delete", entityType: "note", entityId: id, payload: payloadStr, updatedAt: now)
            success = storage.insertSyncOp(op) && success
        }
        return success
    }
    
    // MARK: - Folders
    
    public func folderCreated(_ folder: DBFolder) -> Bool {
        return record(opType: "upsert", entityType: "folder", entityId: folder.id, payload: try? JSONEncoder().encode(folder), updatedAt: Date())
    }
    
    public func folderRenamed(_ folder: DBFolder) -> Bool {
        return record(opType: "upsert", entityType: "folder", entityId: folder.id, payload: try? JSONEncoder().encode(folder), updatedAt: Date())
    }
    
    public func folderSoftDeleted(_ folder: DBFolder) -> Bool {
        return record(opType: "upsert", entityType: "folder", entityId: folder.id, payload: try? JSONEncoder().encode(folder), updatedAt: Date())
    }
    
    public func folderRestored(_ folder: DBFolder) -> Bool {
        return record(opType: "upsert", entityType: "folder", entityId: folder.id, payload: try? JSONEncoder().encode(folder), updatedAt: Date())
    }
    
    // MARK: - Helpers
    
    private func record(opType: String, entityType: String, entityId: String, payload: Data?, updatedAt: Date) -> Bool {
        let payloadStr = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let op = DBSyncOp(id: UUID().uuidString, opType: opType, entityType: entityType, entityId: entityId, payload: payloadStr, updatedAt: updatedAt)
        return storage.insertSyncOp(op)
    }
}
