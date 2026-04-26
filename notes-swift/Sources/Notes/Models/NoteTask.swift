import Foundation

struct NoteTask: Identifiable, Codable, Hashable {
    var id: String
    var userId: String?
    var title: String
    var taskDescription: String
    var isCompleted: Bool
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        title: String = "Untitled",
        taskDescription: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id; self.userId = userId; self.title = title
        self.taskDescription = taskDescription; self.isCompleted = isCompleted
        self.dueDate = dueDate; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.deletedAt = deletedAt
    }
}
