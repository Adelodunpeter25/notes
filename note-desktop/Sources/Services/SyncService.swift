import Foundation

public enum SyncError: LocalizedError, Sendable {
    /// The server rejected our token (401): expired, or signed with a rotated secret.
    case sessionExpired
    
    public var errorDescription: String? {
        switch self {
        case .sessionExpired: return "Your session has expired. Please sign in again."
        }
    }
}

public final class SyncService: @unchecked Sendable {
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
    public func syncData(userId: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard !isSyncing else {
            completion(.failure(NSError(domain: "SyncService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"])))
            return
        }
        isSyncing = true
        // 1. Retrieve the last sync cursor from UserDefaults (per-user)
        let cursor = UserDefaults.standard.string(forKey: cursorKey(for: userId))
        
        // 2. Fetch pending local mutations from the sync_ops queue.
        //    Every op carries the full row, so only the newest op per entity
        //    matters. Collapse the rest (they are dropped locally) so a long
        //    offline backlog becomes a handful of ops instead of thousands.
        let pendingOps = storage.listPendingSyncOps()
        var latest: [String: DBSyncOp] = [:]
        var order: [String] = []
        var superseded: [String] = []
        for op in pendingOps {
            let key = "\(op.entityType):\(op.entityId)"
            if let prev = latest[key] {
                superseded.append(prev.id)
            } else {
                order.append(key)
            }
            latest[key] = op
        }
        if !superseded.isEmpty { _ = storage.deleteSyncOps(ids: superseded) }
        
        var opsPayload: [[String: Any]] = []
        for key in order {
            guard let op = latest[key] else { continue }
            var payloadDict: [String: Any] = [:]
            if let data = op.payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                payloadDict = json
            }
            
            opsPayload.append([
                "id": op.id,
                "type": op.opType,
                "entityType": op.entityType,
                "entityId": op.entityId,
                "updatedAt": TimeUtils.stringFromDate(op.updatedAt),
                "payload": payloadDict
            ])
        }
        
        // 3. Push in small batches so a request never exceeds the server's body
        //    limit. Only ops the server acknowledges are removed locally. The
        //    last response also carries the pull data (changes since `cursor`).
        let batchSize = 100
        let batches: [[[String: Any]]] = opsPayload.isEmpty
            ? [[]]
            : stride(from: 0, to: opsPayload.count, by: batchSize).map {
                Array(opsPayload[$0..<min($0 + batchSize, opsPayload.count)])
            }
        
        pushBatch(0, of: BatchBox(batches), cursor: cursor, userId: userId, completion: completion)
    }
    
    /// Wraps the op batches so they can cross the @Sendable network callback.
    /// Safe because `isSyncing` ensures only one sync touches them at a time.
    private final class BatchBox: @unchecked Sendable {
        let batches: [[[String: Any]]]
        init(_ batches: [[[String: Any]]]) { self.batches = batches }
    }
    
    private func pushBatch(_ index: Int, of box: BatchBox, cursor: String?, userId: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let requestBody: [String: Any] = [
            "cursor": cursor ?? NSNull(),
            "ops": box.batches[index]
        ]
        api.post(path: "sync", body: requestBody) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                self.isSyncing = false
                completion(.failure(error))
            case .success(let (statusCode, data)):
                guard statusCode != 401 else {
                    self.isSyncing = false
                    completion(.failure(SyncError.sessionExpired))
                    return
                }
                guard statusCode == 200 else {
                    self.isSyncing = false
                    completion(.failure(NSError(domain: "SyncService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Sync request failed with status code: \(statusCode)"])))
                    return
                }
                
                guard let jsonResponse = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                    self.isSyncing = false
                    completion(.failure(NSError(domain: "SyncService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from server"])))
                    return
                }
                
                if let processedIds = jsonResponse["processedOpIds"] as? [String], !processedIds.isEmpty {
                    _ = self.storage.deleteSyncOps(ids: processedIds)
                }
                
                if index + 1 < box.batches.count {
                    self.pushBatch(index + 1, of: box, cursor: cursor, userId: userId, completion: completion)
                } else {
                    self.isSyncing = false
                    self.applyPull(jsonResponse, userId: userId, completion: completion)
                }
            }
        }
    }
    
    /// Persists the new cursor and applies folders, notes and tombstones from a sync response.
    private func applyPull(_ jsonResponse: [String: Any], userId: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        // Update the sync cursor (per-user)
        if let nextCursor = jsonResponse["nextCursor"] as? String {
            UserDefaults.standard.set(nextCursor, forKey: cursorKey(for: userId))
        }
        
        // Folders first due to FK constraints
        if let folders = jsonResponse["folders"] as? [[String: Any]] {
            for f in folders {
                guard let id = f["id"] as? String,
                      let name = f["name"] as? String,
                      let uid = f["userId"] as? String else { continue }
                let deletedAt = (f["deletedAt"] as? String).flatMap { TimeUtils.dateFromString($0) }
                let folder = DBFolder(id: id, name: name, userId: uid, deletedAt: deletedAt)
                _ = storage.insertFolder(folder)
            }
        }
        
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
                _ = storage.insertNote(note)
            }
        }
        
        // Hard/soft delete tombstones
        if let deleted = jsonResponse["deleted"] as? [[String: Any]] {
            for d in deleted {
                guard let entityId = d["entityId"] as? String,
                      let entityType = d["entityType"] as? String,
                      let deletedAtStr = d["deletedAt"] as? String,
                      let deletedAt = TimeUtils.dateFromString(deletedAtStr) else { continue }
                
                if entityType == "note" {
                    if var note = storage.getNote(id: entityId) {
                        note.deletedAt = deletedAt
                        _ = storage.updateNote(note)
                    }
                } else if entityType == "folder" {
                    _ = storage.clearFolderFromNotes(folderId: entityId)
                    _ = storage.deleteFolder(id: entityId)
                }
            }
        }
        
        completion(.success(()))
    }
}
