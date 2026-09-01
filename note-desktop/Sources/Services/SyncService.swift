import Foundation

public final class SyncService {
    private let storage: StorageService
    private let api: ApiService
    
    private let cursorKeyBase = "sync_cursor"
    private var isSyncing = false
    
    public init(storage: StorageService, api: ApiService) {
        self.storage = storage
        self.api = api
    }
    
    private func cursorKey(for userId: String) -> String {
        return "\(cursorKeyBase)_\(userId)"
    }
    
    /// Synchronizes the local database with the remote sync server using ApiService.
    public func syncData(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isSyncing else {
            completion(.failure(NSError(domain: "SyncService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"])))
            return
        }
        isSyncing = true
        // 1. Retrieve the last sync cursor from UserDefaults (per-user)
        let cursor = UserDefaults.standard.string(forKey: cursorKey(for: userId))
        
        // 2. Fetch pending local mutations from the sync_ops queue
        let pendingOps = storage.listPendingSyncOps()
        
        // Map sync operations to JSON structures expected by the server
        var opsPayload: [[String: Any]] = []
        for op in pendingOps {
            var payloadDict: [String: Any] = [:]
            if let data = op.payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                payloadDict = json
            }
            
            let mappedOp: [String: Any] = [
                "id": op.id,
                "type": op.opType,
                "entityType": op.entityType,
                "entityId": op.entityId,
                "updatedAt": TimeUtils.stringFromDate(op.updatedAt),
                "payload": payloadDict
            ]
            opsPayload.append(mappedOp)
        }
        
        let requestBody: [String: Any] = [
            "cursor": cursor ?? NSNull(),
            "ops": opsPayload
        ]
        
        api.post(path: "sync", body: requestBody) { [weak self] result in
            guard let self = self else { return }
            defer { self.isSyncing = false }
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (statusCode, data)):
                guard statusCode == 200 else {
                    completion(.failure(NSError(domain: "SyncService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Sync request failed with status code: \(statusCode)"])))
                    return
                }
                
                do {
                    guard let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        completion(.failure(NSError(domain: "SyncService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from server"])))
                        return
                    }
                    
                    // 3. Clear processed local mutations returned by the server
                    if let processedIds = jsonResponse["processedOpIds"] as? [String], !processedIds.isEmpty {
                        _ = self.storage.deleteSyncOps(ids: processedIds)
                    }
                    
                    // 4. Update the sync cursor in UserDefaults
                    if let nextCursor = jsonResponse["nextCursor"] as? String {
                        UserDefaults.standard.set(nextCursor, forKey: self.cursorKey(for: userId))
                    }
                    
                    // 5. Apply incoming folder modifications (folders first due to FK constraints)
                    if let folders = jsonResponse["folders"] as? [[String: Any]] {
                        for f in folders {
                            guard let id = f["id"] as? String,
                                  let name = f["name"] as? String,
                                  let uid = f["userId"] as? String else { continue }
                            let deletedAt = (f["deletedAt"] as? String).flatMap { TimeUtils.dateFromString($0) }
                            let folder = DBFolder(id: id, name: name, userId: uid, deletedAt: deletedAt)
                            _ = self.storage.insertFolder(folder)
                        }
                    }
                    
                    // 6. Apply incoming note modifications
                    if let notes = jsonResponse["notes"] as? [[String: Any]] {
                        for n in notes {
                            guard let id = n["id"] as? String,
                                  let uid = n["userId"] as? String else { continue }
                            let title = n["title"] as? String ?? ""
                            let content = n["content"] as? String ?? ""
                            let isPinned = (n["isPinned"] as? Bool) ?? ((n["isPinned"] as? Int) != 0)
                            let folderId = n["folderId"] as? String
                            
                            let createdAt = (n["createdAt"] as? String).flatMap { TimeUtils.dateFromString($0) } ?? Date()
                            let updatedAt = (n["updatedAt"] as? String).flatMap { TimeUtils.dateFromString($0) } ?? Date()
                            let deletedAt = (n["deletedAt"] as? String).flatMap { TimeUtils.dateFromString($0) }
                            
                            let note = DBNote(
                                id: id,
                                title: title,
                                content: content,
                                createdAt: createdAt,
                                updatedAt: updatedAt,
                                isPinned: isPinned,
                                folderId: folderId,
                                userId: uid,
                                deletedAt: deletedAt
                            )
                            _ = self.storage.insertNote(note)
                        }
                    }
                    
                    // 7. Process hard/soft delete tombstones
                    if let deleted = jsonResponse["deleted"] as? [[String: Any]] {
                        for d in deleted {
                            guard let entityId = d["entityId"] as? String,
                                  let entityType = d["entityType"] as? String,
                                  let deletedAtStr = d["deletedAt"] as? String,
                                  let deletedAt = TimeUtils.dateFromString(deletedAtStr) else { continue }
                             
                            if entityType == "note" {
                                if var note = self.storage.getNote(id: entityId) {
                                    note.deletedAt = deletedAt
                                    _ = self.storage.updateNote(note)
                                }
                            } else if entityType == "folder" {
                                _ = self.storage.clearFolderFromNotes(folderId: entityId)
                                _ = self.storage.deleteFolder(id: entityId)
                            }
                        }
                    }
                    
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
