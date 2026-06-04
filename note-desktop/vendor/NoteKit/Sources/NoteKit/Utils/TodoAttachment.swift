import AppKit

public final class TodoAttachmentViewProvider: NSTextAttachmentViewProvider {
    public override func loadView() {
        let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(buttonToggled(_:)))
        button.state = (textAttachment as? TodoAttachment)?.isChecked == true ? .on : .off
        self.view = button
    }
    
    @objc private func buttonToggled(_ sender: NSButton) {
        guard let attachment = textAttachment as? TodoAttachment else { return }
        let newState = sender.state == .on
        attachment.isChecked = newState
        attachment.onToggle?(newState)
    }
}

public final class TodoAttachment: NSTextAttachment {
    public static let fileType = "com.notekit.todo"
    
    public static func register() {
        NSTextAttachment.registerViewProviderClass(TodoAttachmentViewProvider.self, forFileType: fileType)
    }
    
    public var isChecked: Bool
    public var blockId: UUID
    public var onToggle: ((Bool) -> Void)?
    
    public init(blockId: UUID, isChecked: Bool, onToggle: ((Bool) -> Void)? = nil) {
        self.blockId = blockId
        self.isChecked = isChecked
        self.onToggle = onToggle
        super.init(data: nil, ofType: TodoAttachment.fileType)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
