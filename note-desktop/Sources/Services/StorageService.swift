import Foundation

public final class StorageService {
    private let db: Database
    
    public init(database: Database) {
        self.db = database
    }
    
    // MARK: - Users
    
    public func insertUser(_ user: DBUser) -> Bool {
        let sql = "INSERT OR REPLACE INTO users (id, username, email) VALUES (?, ?, ?);"
        return db.execute(sql: sql, params: [user.id, user.username, user.email])
    }
    
    public func getUser(id: String) -> DBUser? {
        let sql = "SELECT * FROM users WHERE id = ?;"
        let results = db.query(sql: sql, params: [id])
        guard let row = results.first else { return nil }
        return DBUser(
            id: row["id"] as? String ?? "",
            username: row["username"] as? String ?? "",
            email: row["email"] as? String ?? ""
        )
    }
    
    // MARK: - Folders
    
    public func insertFolder(_ folder: DBFolder) -> Bool {
        let sql = "INSERT OR REPLACE INTO folders (id, name, userId, deletedAt) VALUES (?, ?, ?, ?);"
        let deletedAtStr: Any = folder.deletedAt != nil ? TimeUtils.stringFromDate(folder.deletedAt!) : NSNull()
        return db.execute(sql: sql, params: [folder.id, folder.name, folder.userId, deletedAtStr])
    }
    
    public func updateFolder(_ folder: DBFolder) -> Bool {
        let sql = "UPDATE folders SET name = ?, userId = ?, deletedAt = ? WHERE id = ?;"
        let deletedAtStr: Any = folder.deletedAt != nil ? TimeUtils.stringFromDate(folder.deletedAt!) : NSNull()
        return db.execute(sql: sql, params: [folder.name, folder.userId, deletedAtStr, folder.id])
    }
    
    public func listActiveFolders(userId: String) -> [DBFolder] {
        let sql = "SELECT * FROM folders WHERE userId = ? AND (deletedAt IS NULL OR deletedAt = '');"
        let results = db.query(sql: sql, params: [userId])
        return results.map { mapFolder($0) }
    }
    
    public func getFolder(id: String) -> DBFolder? {
        let sql = "SELECT * FROM folders WHERE id = ?;"
        let results = db.query(sql: sql, params: [id])
        guard let row = results.first else { return nil }
        return mapFolder(row)
    }
    
    public func deleteFolder(id: String) -> Bool {
        let sql = "DELETE FROM folders WHERE id = ?;"
        return db.execute(sql: sql, params: [id])
    }
    
    // MARK: - Notes
    
    public func insertNote(_ note: DBNote) -> Bool {
        let sql = "INSERT OR REPLACE INTO notes (id, title, content, createdAt, updatedAt, isPinned, folderId, userId, deletedAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
        return db.execute(sql: sql, params: [
            note.id,
            note.title,
            note.content,
            TimeUtils.stringFromDate(note.createdAt),
            TimeUtils.stringFromDate(note.updatedAt),
            note.isPinned ? 1 : 0,
            note.folderId ?? NSNull(),
            note.userId,
            note.deletedAt.map { TimeUtils.stringFromDate($0) } ?? NSNull()
        ])
    }
    
    public func updateNote(_ note: DBNote) -> Bool {
        let sql = "UPDATE notes SET title = ?, content = ?, createdAt = ?, updatedAt = ?, isPinned = ?, folderId = ?, userId = ?, deletedAt = ? WHERE id = ?;"
        return db.execute(sql: sql, params: [
            note.title,
            note.content,
            TimeUtils.stringFromDate(note.createdAt),
            TimeUtils.stringFromDate(note.updatedAt),
            note.isPinned ? 1 : 0,
            note.folderId ?? NSNull(),
            note.userId,
            note.deletedAt.map { TimeUtils.stringFromDate($0) } ?? NSNull(),
            note.id
        ])
    }
    
    public func getNote(id: String) -> DBNote? {
        let sql = "SELECT * FROM notes WHERE id = ?;"
        let results = db.query(sql: sql, params: [id])
        guard let row = results.first else { return nil }
        return mapNote(row)
    }
    
    public func listActiveNotes(userId: String) -> [DBNote] {
        let sql = "SELECT * FROM notes WHERE userId = ? AND (deletedAt IS NULL OR deletedAt = '') ORDER BY isPinned DESC, updatedAt DESC;"
        let results = db.query(sql: sql, params: [userId])
        return results.map { mapNote($0) }
    }
    
    public func listNotesInFolder(userId: String, folderId: String) -> [DBNote] {
        let sql = "SELECT * FROM notes WHERE userId = ? AND folderId = ? AND (deletedAt IS NULL OR deletedAt = '') ORDER BY isPinned DESC, updatedAt DESC;"
        let results = db.query(sql: sql, params: [userId, folderId])
        return results.map { mapNote($0) }
    }
    
    public func listTrashNotes(userId: String) -> [DBNote] {
        let sql = "SELECT * FROM notes WHERE userId = ? AND (deletedAt IS NOT NULL AND deletedAt != '') ORDER BY deletedAt DESC;"
        let results = db.query(sql: sql, params: [userId])
        return results.map { mapNote($0) }
    }
    
    public func deleteNotePermanently(id: String) -> Bool {
        let sql = "DELETE FROM notes WHERE id = ?;"
        return db.execute(sql: sql, params: [id])
    }
    
    public func clearFolderFromNotes(folderId: String) -> Bool {
        let sql = "UPDATE notes SET folderId = NULL WHERE folderId = ?;"
        return db.execute(sql: sql, params: [folderId])
    }
    
    public func emptyTrash(userId: String) -> Bool {
        let sql = "DELETE FROM notes WHERE userId = ? AND (deletedAt IS NOT NULL AND deletedAt != '');"
        return db.execute(sql: sql, params: [userId])
    }
    
    // MARK: - Sync Operations
    
    public func insertSyncOp(_ op: DBSyncOp) -> Bool {
        let sql = "INSERT OR REPLACE INTO sync_ops (id, opType, entityType, entityId, payload, updatedAt) VALUES (?, ?, ?, ?, ?, ?);"
        return db.execute(sql: sql, params: [
            op.id,
            op.opType,
            op.entityType,
            op.entityId,
            op.payload,
            TimeUtils.stringFromDate(op.updatedAt)
        ])
    }
    
    public func listPendingSyncOps() -> [DBSyncOp] {
        let sql = "SELECT * FROM sync_ops ORDER BY updatedAt ASC;"
        let results = db.query(sql: sql)
        return results.map { row in
            DBSyncOp(
                id: row["id"] as? String ?? "",
                opType: row["opType"] as? String ?? "",
                entityType: row["entityType"] as? String ?? "",
                entityId: row["entityId"] as? String ?? "",
                payload: row["payload"] as? String ?? "",
                updatedAt: (row["updatedAt"] as? String).flatMap { TimeUtils.dateFromString($0) } ?? Date()
            )
        }
    }
    
    public func deleteSyncOps(ids: [String]) -> Bool {
        if ids.isEmpty { return true }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        let sql = "DELETE FROM sync_ops WHERE id IN (\(placeholders));"
        return db.execute(sql: sql, params: ids)
    }
    
    public func countPendingSyncOps() -> Int {
        let sql = "SELECT COUNT(*) as count FROM sync_ops;"
        let results = db.query(sql: sql)
        return results.first?["count"] as? Int ?? 0
    }
    
    // MARK: - Helpers
    
    private func mapFolder(_ row: [String: Any]) -> DBFolder {
        return DBFolder(
            id: row["id"] as? String ?? "",
            name: row["name"] as? String ?? "",
            userId: row["userId"] as? String ?? "",
            deletedAt: (row["deletedAt"] as? String).flatMap { TimeUtils.dateFromString($0) }
        )
    }
    
    private func mapNote(_ row: [String: Any]) -> DBNote {
        let isPinnedInt = row["isPinned"] as? Int ?? 0
        return DBNote(
            id: row["id"] as? String ?? "",
            title: row["title"] as? String ?? "",
            content: row["content"] as? String ?? "",
            createdAt: (row["createdAt"] as? String).flatMap { TimeUtils.dateFromString($0) } ?? Date(),
            updatedAt: (row["updatedAt"] as? String).flatMap { TimeUtils.dateFromString($0) } ?? Date(),
            isPinned: isPinnedInt != 0,
            folderId: row["folderId"] as? String,
            userId: row["userId"] as? String ?? "",
            deletedAt: (row["deletedAt"] as? String).flatMap { TimeUtils.dateFromString($0) }
        )
    }
}
