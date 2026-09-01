import Foundation

public enum BlockType: String, Codable, Sendable {
    case title
    case heading
    case subheading
    case text
    case bulletList
    case numberedList
    case dashedList
    case todo
}
