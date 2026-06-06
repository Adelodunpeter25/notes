import AppKit

public final class NoteList: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    // MARK: - Properties
    private let noteService: NoteService
    private let storage: StorageService
    private var viewModel: NoteListViewModel?
    
    private let searchField = SearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let headerLabel = NSTextField(labelWithString: "All Notes")
    private let addNoteButton = NSButton()
    
    private var userId: String = ""
    private var isTrashSelected = false
    private var contextMenuNote: DBNote?
    
    public var onNoteSelected: ((DBNote?) -> Void)?
    public var onAddNoteTapped: (() -> Void)?
    public var onNoteUpdated: ((DBNote?) -> Void)?
    
    // MARK: - Initializer
    public init(noteService: NoteService, storage: StorageService) {
        self.noteService = noteService
        self.storage = storage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 600))
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 1. Title + Action Stack
        let titleStack = NSStackView()
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY
        titleStack.spacing = 8
        
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        headerLabel.textColor = .labelColor
        
        addNoteButton.isBordered = false
        addNoteButton.imagePosition = .imageOnly
        addNoteButton.bezelStyle = .texturedRounded
        addNoteButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Note")
        addNoteButton.target = self
        addNoteButton.action = #selector(addButtonTapped)
        addNoteButton.translatesAutoresizingMaskIntoConstraints = false
        addNoteButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        addNoteButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        titleStack.addArrangedSubview(headerLabel)
        titleStack.addArrangedSubview(NSView()) // spacer
        titleStack.addArrangedSubview(addNoteButton)
        
        // 2. Search Field
        searchField.delegate = self
        
        // 3. Table View
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.rowHeight = 52
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NoteColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        
        // Layout views
        view.addSubview(titleStack)
        view.addSubview(searchField)
        view.addSubview(scrollView)
        
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleStack.heightAnchor.constraint(equalToConstant: 28),
            
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 10),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Context menu setup
        let menu = NoteContextMenu(target: self, pinAction: #selector(contextPinTapped), deleteAction: #selector(contextDeleteTapped), restoreAction: #selector(contextRestoreTapped))
        menu.delegate = self
        tableView.menu = menu
    }
    
    // MARK: - Public Interface
    public func setNotes(_ notes: [DBNote], title: String, userId: String) {
        self.userId = userId
        self.headerLabel.stringValue = title
        self.isTrashSelected = (title == "Trash")
        
        if viewModel == nil {
            viewModel = NoteListViewModel(noteService: noteService, storage: storage, userId: userId)
        }
        
        viewModel?.updateNotes(notes, searchquery: searchField.stringValue)
        updateHeaderButtonState()
        tableView.reloadData()
    }
    
    private func updateHeaderButtonState() {
        if isTrashSelected {
            addNoteButton.image = NSImage(systemSymbolName: "trash.slash", accessibilityDescription: "Empty Trash")
            addNoteButton.toolTip = "Empty Trash"
        } else {
            addNoteButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Note")
            addNoteButton.toolTip = "New Note"
        }
    }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ThemeRowView"), owner: self) as? ThemeTableRowView
        if rowView == nil {
            rowView = ThemeTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier("ThemeRowView")
        }
        return rowView
    }
    
    public func selectNote(_ note: DBNote?) {
        guard let note = note, let viewModel = viewModel else {
            tableView.deselectAll(nil)
            return
        }
        for (index, item) in viewModel.rowItems.enumerated() {
            if case .note(let dbNote) = item, dbNote.id == note.id {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index)
                return
            }
        }
    }
    
    // MARK: - Search
    private func filterNotes() {
        viewModel?.filterNotes(query: searchField.stringValue)
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc func addButtonTapped() {
        if isTrashSelected {
            ConfirmDialog.show(
                title: "Empty Trash",
                message: "Are you sure you want to permanently delete all notes in the Trash?",
                actionTitle: "Empty Trash"
            ) { [weak self] in
                guard let self = self else { return }
                if self.noteService.emptyTrash(userId: self.userId) {
                    self.onNoteSelected?(nil)
                    self.onNoteUpdated?(nil)
                }
            }
        } else {
            onAddNoteTapped?()
        }
    }
    
    @objc func contextPinTapped() {
        guard let note = contextMenuNote else { return }

        let newPinState = !note.isPinned
        if noteService.pinNote(note, isPinned: newPinState) {
            var updated = note
            updated.isPinned = newPinState
            onNoteUpdated?(updated)
        }
    }
    
    @objc func contextDeleteTapped() {
        guard let note = contextMenuNote else { return }

        if note.deletedAt != nil {
            ConfirmDialog.show(title: "Delete Permanently", message: "Are you sure you want to permanently delete this note?") { [weak self] in
                guard let self = self else { return }
                if self.noteService.deleteNotePermanently(note) {
                    self.onNoteSelected?(nil)
                    self.onNoteUpdated?(nil)
                }
            }
        } else {
            if noteService.softDeleteNote(note) {
                self.onNoteSelected?(nil)
                var updated = note
                updated.deletedAt = Date()
                onNoteUpdated?(updated)
            }
        }
    }
    
    @objc func contextRestoreTapped() {
        guard let note = contextMenuNote,
              note.deletedAt != nil else { return }

        if noteService.restoreNote(note) {
            var updated = note
            updated.deletedAt = nil
            onNoteSelected?(updated)
            onNoteUpdated?(updated)
        }
    }
    
    @objc func contextMoveTapped(_ sender: NSMenuItem) {
        guard let note = contextMenuNote else { return }
        let folderId = sender.representedObject as? String
        
        if noteService.moveNoteToFolder(note, folderId: folderId) {
            var updated = note
            updated.folderId = folderId
            onNoteUpdated?(updated)
        }
    }
    
    // MARK: - NSSearchFieldDelegate
    public func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSSearchField == searchField {
            filterNotes()
        }
    }
    
    // MARK: - NSTableViewDataSource
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel?.rowItems.count ?? 0
    }
    
    // MARK: - NSTableViewDelegate
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard let item = viewModel?.rowItems[row] else { return false }
        switch item {
        case .header:
            return true
        case .note:
            return false
        }
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let item = viewModel?.rowItems[row] else { return 52 }
        switch item {
        case .header:
            return 22
        case .note:
            return 52
        }
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = viewModel?.rowItems[row] else { return nil }
        
        switch item {
        case .header(let title):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderRowCell"), owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
            cell.identifier = NSUserInterfaceItemIdentifier("HeaderRowCell")
            cell.stringValue = title
            cell.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            cell.textColor = .secondaryLabelColor
            return cell
            
        case .note(let note):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NoteCell"), owner: self) as? NoteCellView ?? NoteCellView(frame: .zero)
            cell.identifier = NSUserInterfaceItemIdentifier("NoteCell")
            cell.titleLabel.stringValue = note.title.isEmpty ? "Untitled" : note.title
            
            let timeStr = TimeUtils.formatCardTime(for: note.updatedAt)
            let snippet = NoteCellView.previewFromContent(note.content)
            cell.subtitleLabel.stringValue = "\(timeStr)   \(snippet)"
            
            cell.pinImageView.isHidden = !note.isPinned
            return cell
        }
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow == -1 {
            onNoteSelected?(nil)
            return
        }
        
        guard let item = viewModel?.rowItems[selectedRow] else { return }
        switch item {
        case .header:
            onNoteSelected?(nil)
        case .note(let note):
            onNoteSelected?(note)
        }
    }
}

extension NoteList: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        let clickedRow = tableView.clickedRow
        guard let viewModel = viewModel,
              clickedRow != -1,
              case .note(let note) = viewModel.rowItems[clickedRow],
              let contextMenu = menu as? NoteContextMenu else {
            menu.removeAllItems()
            contextMenuNote = nil
            return
        }

        contextMenuNote = note
        tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)

        let folders = storage.listActiveFolders(userId: userId)
        
        contextMenu.update(
            note: note,
            folders: folders,
            target: self,
            pinAction: #selector(contextPinTapped),
            deleteAction: #selector(contextDeleteTapped),
            restoreAction: #selector(contextRestoreTapped),
            moveAction: #selector(contextMoveTapped)
        )
    }
}
