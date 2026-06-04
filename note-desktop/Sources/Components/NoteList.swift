import AppKit

public final class NoteList: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    // MARK: - Row Representation
    private enum RowItem {
        case header(String)
        case note(DBNote)
    }
    
    // MARK: - Properties
    private let noteService: NoteService
    private let storage: StorageService
    
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let headerLabel = NSTextField(labelWithString: "All Notes")
    private let addNoteButton = NSButton()
    
    private var allNotes: [DBNote] = []
    private var filteredNotes: [DBNote] = []
    private var rowItems: [RowItem] = []
    
    private var userId: String = ""
    
    public var onNoteSelected: ((DBNote?) -> Void)?
    public var onAddNoteTapped: (() -> Void)?
    
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
        searchField.placeholderString = "Search notes"
        searchField.delegate = self
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        
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
        let menu = NSMenu()
        menu.addItem(withTitle: "Pin / Unpin Note", action: #selector(contextPinTapped), keyEquivalent: "")
        menu.addItem(withTitle: "Move to Trash", action: #selector(contextDeleteTapped), keyEquivalent: "")
        menu.addItem(withTitle: "Restore Note", action: #selector(contextRestoreTapped), keyEquivalent: "")
        tableView.menu = menu
    }
    
    // MARK: - Public Interface
    public func setNotes(_ notes: [DBNote], title: String, userId: String) {
        self.allNotes = notes
        self.userId = userId
        self.headerLabel.stringValue = title
        filterNotes()
    }
    
    public func selectNote(_ note: DBNote?) {
        guard let note = note else {
            tableView.deselectAll(nil)
            return
        }
        for (index, item) in rowItems.enumerated() {
            if case .note(let dbNote) = item, dbNote.id == note.id {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index)
                return
            }
        }
    }
    
    // MARK: - Search
    private func filterNotes() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredNotes = allNotes
        } else {
            filteredNotes = noteService.searchNotes(query: query, userId: userId)
        }
        updateRowItems()
    }
    
    private func updateRowItems() {
        var newItems: [RowItem] = []
        
        let pinned = filteredNotes.filter { $0.isPinned }
        let unpinned = filteredNotes.filter { !$0.isPinned }
        
        if !pinned.isEmpty {
            newItems.append(.header("Pinned"))
            for note in pinned {
                newItems.append(.note(note))
            }
        }
        
        var currentSection: String? = nil
        for note in unpinned {
            let section = TimeUtils.getNoteSection(for: note.updatedAt)
            if section != currentSection {
                currentSection = section
                newItems.append(.header(section))
            }
            newItems.append(.note(note))
        }
        
        self.rowItems = newItems
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        onAddNoteTapped?()
    }
    
    @objc private func contextPinTapped() {
        let clickedRow = tableView.clickedRow
        guard clickedRow != -1,
              case .note(let note) = rowItems[clickedRow] else { return }
        
        _ = noteService.pinNote(note, isPinned: !note.isPinned)
        // Parent view controller will reload data through model sync
        onNoteSelected?(note)
    }
    
    @objc private func contextDeleteTapped() {
        let clickedRow = tableView.clickedRow
        guard clickedRow != -1,
              case .note(let note) = rowItems[clickedRow] else { return }
        
        if note.deletedAt != nil {
            // Hard delete
            ConfirmDialog.show(title: "Delete Permanently", message: "Are you sure you want to permanently delete this note?") { [weak self] in
                if self?.noteService.deleteNotePermanently(note) == true {
                    self?.onNoteSelected?(nil)
                }
            }
        } else {
            // Soft delete
            if noteService.softDeleteNote(note) {
                onNoteSelected?(nil)
            }
        }
    }
    
    @objc private func contextRestoreTapped() {
        let clickedRow = tableView.clickedRow
        guard clickedRow != -1,
              case .note(let note) = rowItems[clickedRow],
              note.deletedAt != nil else { return }
        
        if noteService.restoreNote(note) {
            onNoteSelected?(note)
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
        return rowItems.count
    }
    
    // MARK: - NSTableViewDelegate
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        switch rowItems[row] {
        case .header:
            return true
        case .note:
            return false
        }
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rowItems[row] {
        case .header:
            return 22
        case .note:
            return 52
        }
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = rowItems[row]
        
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
        
        switch rowItems[selectedRow] {
        case .header:
            onNoteSelected?(nil)
        case .note(let note):
            onNoteSelected?(note)
        }
    }
}

// MARK: - Note Cell View
fileprivate final class NoteCellView: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let pinImageView = NSImageView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)
        
        pinImageView.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinImageView.imageScaling = .scaleProportionallyDown
        pinImageView.contentTintColor = AppColors.accent
        addSubview(pinImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinImageView.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            pinImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pinImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            pinImageView.widthAnchor.constraint(equalToConstant: 12),
            pinImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    public static func previewFromContent(_ content: String) -> String {
        let lines = NoteUtils.extractLines(from: content)
        if lines.count <= 1 {
            return "No additional text"
        }
        let remaining = lines.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if remaining.isEmpty {
            return "No additional text"
        }
        return remaining.joined(separator: " ")
    }
}
