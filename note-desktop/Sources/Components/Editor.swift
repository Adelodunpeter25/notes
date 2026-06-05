import AppKit
import NoteKit

public final class Editor: NSViewController, NoteBlockStoreDelegate, EditorToolbarDelegate {
    private let noteService: NoteService
    private var activeNote: DBNote?
    
    // UI Outlets
    private let headerLabel = NSTextField(labelWithString: "")
    private let textContentStorage = NSTextContentStorage()
    private let textLayoutManager = NSTextLayoutManager()
    private let textContainer = NSTextContainer(containerSize: .zero)
    private var textView: NSTextView!
    private let toolbar = EditorToolbar()
    private let scrollView = NSScrollView()
    
    private var store: BlockStore?
    private var coordinator: NoteDocumentCoordinator?
    
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
        
        // 2. Setup TextKit 2 pipeline
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.textContainer = textContainer
        
        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width, .height]
        textView.font = NSFont.systemFont(ofSize: 14)
        
        scrollView.hasVerticalScroller = true
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
        
        // Convert AppFlowy editor JSON format to NoteKit blocks representation
        let blocks = AppFlowyConverter.toBlocks(jsonString: note.content)
        
        // Initialize new memory store
        let newStore = BlockStore(blocks: blocks)
        newStore.delegate = self
        self.store = newStore
        
        // Wire up coordinator to text content storage
        let newCoordinator = NoteDocumentCoordinator(store: newStore, textContentStorage: textContentStorage)
        textView.delegate = newCoordinator
        self.coordinator = newCoordinator
    }
    
    private func saveNoteContent() {
        guard var note = activeNote, let store = store else { return }
        
        let newJSON = AppFlowyConverter.toAppFlowyJSON(blocks: store.blocks)
        note.content = newJSON
        note.title = NoteUtils.titleFromContent(newJSON)
        
        if noteService.updateNote(note) {
            self.activeNote = note
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            onNoteUpdated?(note)
        }
    }
    
    // MARK: - NoteBlockStoreDelegate
    
    public func blockStore(_ store: BlockStore, didUpdateBlocks blocks: [Block]) {
        saveNoteContent()
    }
    
    public func blockStore(_ store: BlockStore, didUpdateBlock block: Block, atIndex index: Int) {
        saveNoteContent()
    }
    
    public func blockStore(_ store: BlockStore, didInsertBlock block: Block, atIndex index: Int) {
        saveNoteContent()
    }
    
    public func blockStore(_ store: BlockStore, didRemoveBlockWithId id: UUID, atIndex index: Int) {
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
                self?.store = nil
                self?.coordinator = nil
                self?.textView.string = ""
                self?.headerLabel.stringValue = ""
                self?.onNoteUpdated?(nil)
            }
        }
    }
    
    public func toolbarDidTapCheckbox(_ toolbar: EditorToolbar) {
        // Toggle checklists insertion at active layout ranges
    }
}
