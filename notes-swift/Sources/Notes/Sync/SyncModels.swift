import Foundation

// MARK: - Request

struct SyncRequest: Encodable {
    let cursor: String?
    let ops: [SyncOperation]
}

struct SyncOperation: Encodable {
    let id: String
    let type: String        // "upsert" | "delete"
    let entityType: String  // "note" | "folder" | "task"
    let entityId: String
    let updatedAt: String
    let payload: [String: AnyCodable]?
}

// MARK: - Response

struct SyncResponse: Decodable {
    let nextCursor: String
    let notes: [NoteDTO]
    let folders: [FolderDTO]
    let tasks: [TaskDTO]
    let deleted: [SyncTombstone]
}

struct SyncTombstone: Decodable {
    let entityType: String
    let entityId: String
    let deletedAt: String
}

// MARK: - DTOs (server shape, camelCase after decoding)

struct NoteDTO: Decodable {
    let id: String
    let userId: String?
    let folderId: String?
    let title: String
    let content: String
    let isPinned: Bool
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
}

struct FolderDTO: Decodable {
    let id: String
    let userId: String?
    let name: String
    let createdAt: String
    let updatedAt: String
}

struct TaskDTO: Decodable {
    let id: String
    let userId: String?
    let title: String
    let description: String
    let isCompleted: Bool
    let dueDate: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
}

// MARK: - AnyCodable (minimal, for op payloads)

struct AnyCodable: Encodable {
    let value: Any
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String:  try c.encode(v)
        case let v as Bool:    try c.encode(v)
        case let v as Int:     try c.encode(v)
        case let v as Double:  try c.encode(v)
        case Optional<Any>.none: try c.encodeNil()
        default: try c.encodeNil()
        }
    }
}
