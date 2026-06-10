import AppKit

public final class Editor: NSViewController, NSTextViewDelegate {
    private let noteService: NoteService
    private var activeNote: DBNote?
    
    // UI Outlets
    private let headerLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    
    public var onNoteUpdated: ((DBNote?) -> Void)?
    
    public init(noteService: NoteService) {
        self.noteService = noteService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        // 1. Setup Header Date Display
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.font = NSFont.systemFont(ofSize: 11)
        headerLabel.alignment = .center
        
        // 2. Setup Plain Text Editor
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.delegate = self
        
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        
        scrollView.documentView = textView
        
        // Stack and align layouts
        let stack = NSStackView(views: [headerLabel, scrollView])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .centerX
        stack.distribution = .fill
        
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }
    
    /// Loads a specific database note inside the editor view.
    public func loadNote(_ note: DBNote) {
        if self.activeNote?.id == note.id {
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            return
        }
        
        self.activeNote = note
        
        // Update header
        headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
        
        // Extract plain text from AppFlowy JSON for display
        let blocks = AppFlowyConverter.toBlocks(jsonString: note.content)
        let plainText = blocks.map { $0.content }.joined(separator: "\n")
        textView.string = plainText
    }
    
    private func saveNoteContent() {
        guard var note = activeNote else { return }
        
        let plainText = textView.string
        // Store as a single text block in AppFlowy JSON to maintain system-wide compatibility
        let block = Block(type: .text, content: plainText)
        let newJSON = AppFlowyConverter.toAppFlowyJSON(blocks: [block])
        
        note.content = newJSON
        note.title = NoteUtils.titleFromContent(newJSON)
        
        if noteService.updateNote(note) {
            self.activeNote = note
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            onNoteUpdated?(note)
        }
    }
    
    // MARK: - NSTextViewDelegate
    
    public func textDidChange(_ notification: Notification) {
        saveNoteContent()
    }
}
