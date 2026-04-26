import Foundation

struct Note: Identifiable, Codable, Hashable {
    var id: String
    var userId: String?
    var folderId: String?
    var title: String
    var content: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        folderId: String? = nil,
        title: String = "Untitled",
        content: String = "",
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id; self.userId = userId; self.folderId = folderId
        self.title = title; self.content = content; self.isPinned = isPinned
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.deletedAt = deletedAt
    }
}
