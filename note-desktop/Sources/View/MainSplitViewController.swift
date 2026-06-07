import AppKit

public final class MainSplitViewController: NSSplitViewController {
    
    // MARK: - Services
    private let storage: StorageService
    private let folderService: FolderService
    private let noteService: NoteService
    private let userId: String
    
    // MARK: - Components
    private let folderList: FolderList
    private let noteList: NoteList
    private let editor: Editor
    
    // MARK: - State
    private var currentSelection: FolderSelection = .allNotes
    
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
            self.currentSelection = selection
            self.loadNotesForCurrentSelection()
        }
        
        // Note List selection changes
        noteList.onNoteSelected = { [weak self] note in
            guard let self = self else { return }
            if let note = note {
                self.editor.loadNote(note)
            } else {
                // Load dummy empty note or clear view
                // Editor handles nil note by clearing backing stores and UI strings
            }
        }
        
        // Add Note action
        noteList.onAddNoteTapped = { [weak self] in
            guard let self = self else { return }
            self.createNewNoteInCurrentSelection()
        }
        
        // Editor update events (saves body / updates titles in list)
        editor.onNoteUpdated = { [weak self] updatedNote in
            guard let self = self else { return }
            // Reload list items to refresh title/snippet in real-time
            self.loadNotesForCurrentSelection(retainSelectedNoteId: updatedNote?.id)
            // Update folder badge counts since note counts changed
            self.folderList.reloadData()
        }
        
        // Note List update events (pin, delete, restore, empty trash)
        noteList.onNoteUpdated = { [weak self] updatedNote in
            guard let self = self else { return }
            self.loadNotesForCurrentSelection(retainSelectedNoteId: updatedNote?.id)
            self.folderList.reloadData()
        }
    }
    
    // MARK: - Public Actions
    public func createNewNote() {
        createNewNoteInCurrentSelection()
    }
    
    public func createNewFolder() {
        folderList.createNewFolder()
    }
    
    // MARK: - Data Synchronization
    public func refreshAllData() {
        folderList.reloadData()
        loadNotesForCurrentSelection()
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
        
        if let selectedId = retainSelectedNoteId {
            if let matchedNote = notes.first(where: { $0.id == selectedId }) {
                noteList.selectNote(matchedNote)
            }
        } else if let firstNote = notes.first {
            noteList.selectNote(firstNote)
            editor.loadNote(firstNote)
        } else {
            noteList.selectNote(nil)
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
        
        let folderId: String?
        if case .folder(let folder) = currentSelection {
            folderId = folder.id
        } else {
            folderId = nil
        }
        
        if let note = noteService.createNote(title: "Untitled", content: "", userId: userId, folderId: folderId) {
            refreshAllData()
            noteList.selectNote(note)
            editor.loadNote(note)
        }
    }
}
