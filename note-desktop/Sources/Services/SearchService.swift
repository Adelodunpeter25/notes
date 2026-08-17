import Foundation

public final class SearchService {
    private let database: Database
    
    public init(database: Database) {
        self.database = database
    }
    
    /// Searches active notes for a given user using the SQLite FTS virtual table.
    public func searchNotes(query: String, userId: String) -> [DBNote] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        
        // Escape special matching characters & build a prefix matching FTS query
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
        let terms = escaped.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { "\($0)*" }
            .joined(separator: " ")
        
        guard !terms.isEmpty else { return [] }
        
        let sql = """
        SELECT DISTINCT n.* FROM notes n
        WHERE n.userId = ? 
          AND (n.deletedAt IS NULL OR n.deletedAt = '')
          AND (
            n.id IN (SELECT id FROM notes_fts WHERE notes_fts MATCH ?)
            OR n.title LIKE ?
            OR n.content LIKE ?
          )
        ORDER BY n.isPinned DESC, n.updatedAt DESC;
        """
        
        let likeTerm = "%\(trimmed)%"
        let results = database.query(sql: sql, params: [userId, terms, likeTerm, likeTerm])
        return results.map { row in
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
}
