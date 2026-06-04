import Foundation

public struct NoteKit {
    public static let version = "1.0.0"
    
    /// Initializes NoteKit and registers custom TextKit 2 attachments.
    public static func initialize() {
        TodoAttachment.register()
    }
}
