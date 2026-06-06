import AppKit

public final class NoteList: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let noteService: NoteService
    private let storage: StorageService
    private var viewModel: NoteListViewModel?
    private var listView: NoteListView { view as! NoteListView }
    
    private var userId: String = ""
    private var isTrashSelected = false
    private var contextMenuNote: DBNote?
    
    public var onNoteSelected: ((DBNote?) -> Void)?
    public var onAddNoteTapped: (() -> Void)?
    public var onNoteUpdated: ((DBNote?) -> Void)?
    
    public init(noteService: NoteService, storage: StorageService) {
        self.noteService = noteService
        self.storage = storage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func loadView() { self.view = NoteListView(frame: NSRect(x: 0, y: 0, width: 280, height: 600)) }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        listView.tableView.dataSource = self
        listView.tableView.delegate = self
        listView.searchField.delegate = self
        listView.addNoteButton.target = self
        listView.addNoteButton.action = #selector(addButtonTapped)
        listView.tableView.menu = NoteContextMenu(target: self, pinAction: #selector(contextPinTapped), deleteAction: #selector(contextDeleteTapped), restoreAction: #selector(contextRestoreTapped), moveAction: #selector(contextMoveTapped))
        listView.tableView.menu?.delegate = self
    }
    
    public func setNotes(_ notes: [DBNote], title: String, userId: String) {
        self.userId = userId
        self.listView.headerLabel.stringValue = title
        self.isTrashSelected = (title == "Trash")
        if viewModel == nil { viewModel = NoteListViewModel(noteService: noteService, storage: storage, userId: userId) }
        viewModel?.updateNotes(notes, searchquery: listView.searchField.stringValue)
        updateHeaderButtonState()
        listView.tableView.reloadData()
    }
    
    private func updateHeaderButtonState() {
        let icon = isTrashSelected ? "trash.slash" : "square.and.pencil"
        listView.addNoteButton.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
    }
    
    public func selectNote(_ note: DBNote?) {
        guard let note = note, let vm = viewModel else { listView.tableView.deselectAll(nil); return }
        if let idx = vm.rowItems.firstIndex(where: { if case .note(let dbNote) = $0 { return dbNote.id == note.id } else { return false } }) {
            listView.tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            listView.tableView.scrollRowToVisible(idx)
        }
    }
    
    @objc func addButtonTapped() {
        if isTrashSelected {
            ConfirmDialog.show(title: "Empty Trash", message: "Permanently delete all notes in Trash?", actionTitle: "Empty Trash") { [weak self] in
                if self?.noteService.emptyTrash(userId: self?.userId ?? "") == true { self?.onNoteSelected?(nil); self?.onNoteUpdated?(nil) }
            }
        } else { onAddNoteTapped?() }
    }
    
    @objc func contextPinTapped() {
        guard let note = contextMenuNote else { return }
        if noteService.pinNote(note, isPinned: !note.isPinned) { var u = note; u.isPinned = !note.isPinned; onNoteUpdated?(u) }
    }
    
    @objc func contextDeleteTapped() {
        guard let note = contextMenuNote else { return }
        if note.deletedAt != nil {
            ConfirmDialog.show(title: "Delete Permanently", message: "Are you sure?") { [weak self] in if self?.noteService.deleteNotePermanently(note) == true { self?.onNoteSelected?(nil); self?.onNoteUpdated?(nil) } }
        } else if noteService.softDeleteNote(note) { self.onNoteSelected?(nil); var u = note; u.deletedAt = Date(); onNoteUpdated?(u) }
    }
    
    @objc func contextRestoreTapped() {
        guard let note = contextMenuNote, note.deletedAt != nil else { return }
        if noteService.restoreNote(note) { var u = note; u.deletedAt = nil; onNoteSelected?(u); onNoteUpdated?(u) }
    }
    
    @objc func contextMoveTapped(_ sender: NSMenuItem) {
        guard let note = contextMenuNote else { return }
        let fId = sender.representedObject as? String
        if noteService.moveNoteToFolder(note, folderId: fId) { var u = note; u.folderId = fId; onNoteUpdated?(u) }
    }
    
    public func controlTextDidChange(_ obj: Notification) { viewModel?.filterNotes(query: listView.searchField.stringValue); listView.tableView.reloadData() }
    
    public func numberOfRows(in tv: NSTableView) -> Int { viewModel?.rowItems.count ?? 0 }
    public func tableView(_ tv: NSTableView, isGroupRow row: Int) -> Bool { if case .header = viewModel?.rowItems[row] { return true } else { return false } }
    public func tableView(_ tv: NSTableView, heightOfRow row: Int) -> CGFloat { if case .header = viewModel?.rowItems[row] { return 22 } else { return 52 } }
    
    public func tableView(_ tv: NSTableView, viewFor tc: NSTableColumn?, row: Int) -> NSView? {
        guard let item = viewModel?.rowItems[row] else { return nil }
        switch item {
        case .header(let title):
            let cell = tv.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderRowCell"), owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
            cell.identifier = NSUserInterfaceItemIdentifier("HeaderRowCell"); cell.stringValue = title; cell.font = NSFont.systemFont(ofSize: 10, weight: .bold); cell.textColor = .secondaryLabelColor; return cell
        case .note(let note):
            let cell = tv.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NoteCell"), owner: self) as? NoteCellView ?? NoteCellView(frame: .zero)
            cell.identifier = NSUserInterfaceItemIdentifier("NoteCell"); cell.titleLabel.stringValue = note.title.isEmpty ? "Untitled" : note.title; cell.subtitleLabel.stringValue = "\(TimeUtils.formatCardTime(for: note.updatedAt))   \(NoteCellView.previewFromContent(note.content))"; cell.pinImageView.isHidden = !note.isPinned; return cell
        }
    }
    
    public func tableView(_ tv: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { tv.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ThemeRowView"), owner: self) as? ThemeTableRowView ?? ThemeTableRowView(frame: .zero) }
    
    public func tableViewSelectionDidChange(_ n: Notification) {
        let row = listView.tableView.selectedRow
        if row == -1 { onNoteSelected?(nil); return }
        if case .note(let note) = viewModel?.rowItems[row] { onNoteSelected?(note) } else { onNoteSelected?(nil) }
    }
}

extension NoteList: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        let row = listView.tableView.clickedRow
        guard let vm = viewModel, row != -1, case .note(let note) = vm.rowItems[row], let ctxMenu = menu as? NoteContextMenu else { menu.removeAllItems(); contextMenuNote = nil; return }
        contextMenuNote = note; listView.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        ctxMenu.update(note: note, folders: storage.listActiveFolders(userId: userId), target: self, pinAction: #selector(contextPinTapped), deleteAction: #selector(contextDeleteTapped), restoreAction: #selector(contextRestoreTapped), moveAction: #selector(contextMoveTapped))
    }
}
