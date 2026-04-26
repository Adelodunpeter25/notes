import Foundation

struct Folder: Identifiable, Codable, Hashable {
    var id: String
    var userId: String?
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id; self.userId = userId; self.name = name
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
