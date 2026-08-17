import AppKit

public final class MainSplitViewController: NSSplitViewController {
    
    // MARK: - Services
    private let storage: StorageService
    private let folderService: FolderService
    private let noteService: NoteService
    private let userId: String
    
    // MARK: - Components
    public let folderList: FolderList
    public let noteList: NoteList
    public let editor: Editor
    
    // MARK: - State
    private var currentSelection: FolderSelection = .allNotes
    private var isUpdating = false
    
    public var onLogout: (() -> Void)?
    
    // MARK: - Initializer
    public init(storage: StorageService, folderService: FolderService, noteService: NoteService, userId: String) {
        self.storage = storage
        self.folderService = folderService
        self.noteService = noteService
        self.userId = userId
        
        self.folderList = FolderList(storage: storage, folderService: folderService, userId: userId)
        self.noteList = NoteList(noteService: noteService, storage: storage)
        self.editor = Editor(noteService: noteService)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSplitViewItems()
        setupBindings()
        refreshAllData()
    }
    
    private func setupSplitViewItems() {
        // 1. Sidebar View Item
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: folderList)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 280
        sidebarItem.canCollapse = true
        addSplitViewItem(sidebarItem)
        
        // 2. Note List View Item
        let listItem = NSSplitViewItem(viewController: noteList)
        listItem.minimumThickness = 220
        listItem.maximumThickness = 340
        addSplitViewItem(listItem)
        
        // 3. Editor View Item
        let editorItem = NSSplitViewItem(viewController: editor)
        editorItem.minimumThickness = 350
        addSplitViewItem(editorItem)
        
        // Modern divider styles
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitView"
    }
    
    private func setupBindings() {
        // Folder Sidebar selection changes
        folderList.onSelectionChanged = { [weak self] selection in
            guard let self = self else { return }
            if self.isUpdating { return }
            self.isUpdating = true
            
            self.noteService.autoDeleteEmptyNotes(userId: self.userId)
            self.currentSelection = selection
            self.loadNotesForCurrentSelection()
            self.folderList.reloadData()
            
            self.isUpdating = false
        }
        
        // Note List selection changes
        noteList.onNoteSelected = { [weak self] note in
            guard let self = self else { return }
            if self.isUpdating { return }
            self.isUpdating = true
            
            self.noteService.autoDeleteEmptyNotes(userId: self.userId)
            self.editor.loadNote(note)
            self.folderList.reloadData()
            
            self.isUpdating = false
        }
        
        // Add Note action
        noteList.onAddNoteTapped = { [weak self] in
            guard let self = self else { return }
            self.createNewNoteInCurrentSelection()
        }
        
        // Editor update events (saves body / updates titles in list)
        editor.onNoteUpdated = { [weak self] updatedNote in
            guard let self = self else { return }
            if self.isUpdating { return }
            self.isUpdating = true
            
            // Reload list items to refresh title/snippet in real-time
            self.loadNotesForCurrentSelection(retainSelectedNoteId: updatedNote?.id)
            // Update folder badge counts since note counts changed
            self.folderList.reloadData()
            
            self.isUpdating = false
        }
        
        // Escape key handling from Note List and Editor
        let handleEscape: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.noteList.clearSelection()
            self.editor.loadNote(nil)
        }
        noteList.onEscapePressed = handleEscape
        editor.onEscapePressed = handleEscape
        
        // Note List update events (pin, delete, restore, empty trash)
        noteList.onNoteUpdated = { [weak self] updatedNote in
            guard let self = self else { return }
            if self.isUpdating { return }
            self.isUpdating = true
            
            self.loadNotesForCurrentSelection(retainSelectedNoteId: updatedNote?.id)
            self.folderList.reloadData()
            
            self.isUpdating = false
        }
    }
    
    // MARK: - Public Actions
    public func createNewNote() {
        createNewNoteInCurrentSelection()
    }
    
    public func createNewFolder() {
        folderList.createNewFolder()
    }
    
    public func toggleFindInCurrentNote() {
        editor.toggleFindBar()
    }
    
    // MARK: - Data Synchronization
    public func refreshAllData() {
        let wasUpdating = isUpdating
        isUpdating = true
        folderList.reloadData()
        loadNotesForCurrentSelection()
        isUpdating = wasUpdating
    }
    
    private func loadNotesForCurrentSelection(retainSelectedNoteId: String? = nil) {
        let notes: [DBNote]
        let title: String
        
        switch currentSelection {
        case .allNotes:
            notes = storage.listActiveNotes(userId: userId)
            title = "All Notes"
        case .folder(let folder):
            notes = storage.listNotesInFolder(userId: userId, folderId: folder.id)
            title = folder.name
        case .trash:
            notes = storage.listTrashNotes(userId: userId)
            title = "Trash"
        }
        
        noteList.setNotes(notes, title: title, userId: userId)
        
        if let selectedId = retainSelectedNoteId, let matchedNote = notes.first(where: { $0.id == selectedId }) {
            noteList.selectNote(matchedNote)
            editor.loadNote(matchedNote)
        } else if let firstNote = notes.first {
            noteList.selectNote(firstNote)
            editor.loadNote(firstNote)
        } else {
            noteList.selectNote(nil)
            editor.loadNote(nil)
        }
    }
    
    private func createNewNoteInCurrentSelection() {
        if case .trash = currentSelection {
            let alert = NSAlert()
            alert.messageText = "Cannot Create Note"
            alert.informativeText = "You cannot create new notes directly inside the Trash folder."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        self.noteService.autoDeleteEmptyNotes(userId: self.userId)
        
        let folderId: String?
        if case .folder(let folder) = currentSelection {
            folderId = folder.id
        } else {
            folderId = nil
        }
        
        if let note = noteService.createNote(title: "Untitled", content: "", userId: userId, folderId: folderId) {
            let wasUpdating = isUpdating
            isUpdating = true
            refreshAllData()
            noteList.selectNote(note)
            editor.loadNote(note)
            isUpdating = wasUpdating
        }
    }
}
