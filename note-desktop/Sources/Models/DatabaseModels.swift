import Foundation

public struct DBUser: Codable {
    public let id: String
    public let username: String
    public let email: String
    
    public init(id: String, username: String, email: String) {
        self.id = id
        self.username = username
        self.email = email
    }
}

public struct DBFolder: Codable {
    public let id: String
    public var name: String
    public let userId: String
    public var deletedAt: Date?
    
    public init(id: String, name: String, userId: String, deletedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.userId = userId
        self.deletedAt = deletedAt
    }
}

public struct DBNote: Codable {
    public let id: String
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var folderId: String?
    public let userId: String
    public var deletedAt: Date?
    
    public init(id: String, title: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date(), isPinned: Bool = false, folderId: String? = nil, userId: String, deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.folderId = folderId
        self.userId = userId
        self.deletedAt = deletedAt
    }
}

public struct DBSyncOp: Codable {
    public let id: String
    public let opType: String
    public let entityType: String
    public let entityId: String
    public let payload: String
    public let updatedAt: Date
    
    public init(id: String, opType: String, entityType: String, entityId: String, payload: String, updatedAt: Date = Date()) {
        self.id = id
        self.opType = opType
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
