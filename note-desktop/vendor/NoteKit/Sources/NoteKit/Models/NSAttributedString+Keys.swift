import Foundation

public extension NSAttributedString.Key {
    /// Tracks which Block ID a character range belongs to.
    static let blockId = NSAttributedString.Key("NoteKit.blockId")
    /// Tracks the block type (heading, checklist, etc.) for layout styling.
    static let blockType = NSAttributedString.Key("NoteKit.blockType")
    /// Track checkbox state (checked/unchecked) for rendering.
    static let blockCheckedState = NSAttributedString.Key("NoteKit.blockCheckedState")
}
