import AppKit
import NoteKit

public final class Editor: NSViewController, EditorToolbarDelegate, NSTextViewDelegate {
    private let noteService: NoteService
    private var activeNote: DBNote?
    
    // UI Outlets
    private let headerLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private let toolbar = EditorToolbar()
    
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
        
        // 3. Setup Toolbar Actions
        toolbar.delegate = self
        
        // Stack and align layouts
        let stack = NSStackView(views: [headerLabel, scrollView, toolbar])
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
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            toolbar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    /// Loads a specific database note inside the editor view.
    public func loadNote(_ note: DBNote) {
        if self.activeNote?.id == note.id {
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            toolbar.isPinned = note.isPinned
            return
        }
        
        self.activeNote = note
        
        // Update header & toolbar states
        headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
        toolbar.isPinned = note.isPinned
        
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
    
    // MARK: - NSTextDelegate
    
    public func textDidChange(_ notification: Notification) {
        saveNoteContent()
    }
    
    // MARK: - EditorToolbarDelegate
    
    public func toolbarDidTapPin(_ toolbar: EditorToolbar) {
        guard let note = activeNote else { return }
        let newPinState = !note.isPinned
        if noteService.pinNote(note, isPinned: newPinState) {
            self.activeNote?.isPinned = newPinState
            toolbar.isPinned = newPinState
            if let active = activeNote {
                onNoteUpdated?(active)
            }
        }
    }
    
    public func toolbarDidTapMove(_ toolbar: EditorToolbar) {
        // Available for routing/popover folder movements in app splitview
    }
    
    public func toolbarDidTapDelete(_ toolbar: EditorToolbar) {
        guard let note = activeNote else { return }
        ConfirmDialog.show(title: "Delete Note", message: "Are you sure you want to move this note to Trash?") { [weak self] in
            if self?.noteService.softDeleteNote(note) == true {
                // Clear selection states
                self?.activeNote = nil
                self?.textView.string = ""
                self?.headerLabel.stringValue = ""
                self?.onNoteUpdated?(nil)
            }
        }
    }
    
    public func toolbarDidTapCheckbox(_ toolbar: EditorToolbar) {
        // Checkboxes not supported in plain-text mode
    }
}
