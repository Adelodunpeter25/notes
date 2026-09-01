import Foundation

public struct Block: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: BlockType
    public var content: String
    public var isChecked: Bool?
    
    public init(id: UUID = UUID(), type: BlockType, content: String, isChecked: Bool? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.isChecked = isChecked
    }
}
