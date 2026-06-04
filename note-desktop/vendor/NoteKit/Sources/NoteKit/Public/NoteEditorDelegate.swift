import AppKit

public protocol NoteEditorDelegate: AnyObject {
    /// Requests the editor to split a block at the current cursor position.
    func editor(_ editor: NSTextView, didRequestSplitBlockAt characterIndex: Int)
    
    /// Requests the editor to change a block type at the cursor (e.g. on Backspace converting list/todo to plain text).
    func editor(_ editor: NSTextView, didRequestChangeBlockTypeAt characterIndex: Int, to type: BlockType)
}
