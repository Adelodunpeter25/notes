import AppKit

public enum FolderSelection: Equatable {
    public static func == (lhs: FolderSelection, rhs: FolderSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allNotes, .allNotes): return true
        case (.trash, .trash): return true
        case (.folder(let lFolder), .folder(let rFolder)):
            return lFolder.id == rFolder.id && lFolder.name == rFolder.name
        default: return false
        }
    }
    case allNotes
    case folder(DBFolder)
    case trash
}

public final class FolderList: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate {
    private let folderService: FolderService
    private let userId: String
    private let viewModel: FolderListViewModel
    private var listView: FolderListView { view as! FolderListView }
    
    public var onSelectionChanged: ((FolderSelection) -> Void)?
    
    public init(storage: StorageService, folderService: FolderService, userId: String) {
        self.folderService = folderService
        self.userId = userId
        self.viewModel = FolderListViewModel(storage: storage, userId: userId)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func loadView() {
        self.view = FolderListView(frame: NSRect(x: 0, y: 0, width: 220, height: 600))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        reloadData()
    }
    
    private func setupBindings() {
        listView.outlineView.dataSource = self
        listView.outlineView.delegate = self
        listView.outlineView.menu = FolderContextMenu()
        listView.outlineView.menu?.delegate = self
        listView.newFolderButton.target = self
        listView.newFolderButton.action = #selector(newFolderButtonTapped)
    }
    
    public func reloadData() {
        viewModel.reloadData()
        listView.outlineView.reloadData()
        listView.outlineView.expandItem(nil, expandChildren: true)
    }
    
    public func createNewFolder() { newFolderButtonTapped() }
    
    @objc private func newFolderButtonTapped() {
        if let folder = folderService.createFolder(name: "Untitled Folder", userId: userId) {
            reloadData()
            selectFolder(folder)
            DispatchQueue.main.async { [weak self] in self?.contextRenameTapped() }
        }
    }
    
    private func selectFolder(_ folder: DBFolder) {
        if let node = viewModel.data.first(where: { $0.folder?.id == folder.id }) {
            let row = listView.outlineView.row(forItem: node)
            if row != -1 { listView.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        }
    }
    
    @objc private func contextRenameTapped() {
        let row = listView.outlineView.selectedRow
        guard row != -1,
              let cell = listView.outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SidebarCellView,
              let node = listView.outlineView.item(atRow: row) as? SidebarNode,
              node.type == .folder else { return }
        
        cell.nameField.isEditable = true
        cell.nameField.isEnabled = true
        listView.outlineView.window?.makeFirstResponder(cell.nameField)
        cell.nameField.currentEditor()?.selectAll(nil)
    }
    
    @objc private func contextDeleteTapped() {
        let row = listView.outlineView.selectedRow
        guard row != -1,
              let node = listView.outlineView.item(atRow: row) as? SidebarNode,
              node.type == .folder, let folder = node.folder else { return }
        
        ConfirmDialog.show(title: "Delete Folder", message: "Are you sure you want to delete '\(folder.name)'?", actionTitle: "Delete") { [weak self] in
            if self?.folderService.deleteFolder(folder) == true {
                self?.reloadData()
                self?.onSelectionChanged?(.allNotes)
            }
        }
    }
    
    // MARK: - NSTextFieldDelegate
    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let row = listView.outlineView.row(for: textField)
        guard row != -1, let node = listView.outlineView.item(atRow: row) as? SidebarNode,
              node.type == .folder, let folder = node.folder else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty && newName != folder.name {
            if folderService.renameFolder(folder, newName: newName) {
                node.folder?.name = newName
                reloadData()
            }
        } else { textField.stringValue = folder.name }
        textField.isEditable = false
    }
    
    // MARK: - NSOutlineView Data & Delegate
    public func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { item == nil ? viewModel.data.count : 0 }
    public func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any { viewModel.data[index] }
    public func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool { false }
    public func outlineView(_ ov: NSOutlineView, shouldSelectItem item: Any) -> Bool { (item as? SidebarNode)?.type != .divider }
    public func outlineView(_ ov: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat { (item as? SidebarNode)?.type == .divider ? 12 : 28 }
    
    public func outlineView(_ ov: NSOutlineView, viewFor tc: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        if node.type == .divider {
            let line = NSView(); line.wantsLayer = true
            line.layer?.backgroundColor = AppColors.divider(isDark: ov.effectiveAppearance.name.rawValue.contains("Dark")).cgColor
            let container = NSView(); container.addSubview(line); line.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12), line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12), line.centerYAnchor.constraint(equalTo: container.centerYAnchor), line.heightAnchor.constraint(equalToConstant: 1)])
            return container
        }
        let cell = ov.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SidebarCell"), owner: self) as? SidebarCellView ?? SidebarCellView(frame: .zero)
        cell.identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        cell.nameField.stringValue = node.name
        cell.nameField.delegate = self
        let icon: String = { switch node.type { case .trash: return "trash"; default: return "folder" } }()
        cell.iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        let count = viewModel.getCount(for: node)
        cell.badgeField.stringValue = count > 0 ? "\(count)" : ""
        return cell
    }
    public func outlineView(_ ov: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("ThemeRowView")
        var rowView = ov.makeView(withIdentifier: identifier, owner: self) as? ThemeTableRowView
        if rowView == nil {
            rowView = ThemeTableRowView(frame: .zero)
            rowView?.identifier = identifier
        }
        return rowView
    }
    
    public func outlineViewSelectionDidChange(_ n: Notification) {
        let row = listView.outlineView.selectedRow
        guard row != -1, let node = listView.outlineView.item(atRow: row) as? SidebarNode else { return }
        switch node.type {
        case .allNotes: onSelectionChanged?(.allNotes)
        case .folder: if let f = node.folder { onSelectionChanged?(.folder(f)) }
        case .trash: onSelectionChanged?(.trash)
        default: break
        }
    }
}

extension FolderList: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        let row = listView.outlineView.clickedRow
        guard let ctxMenu = menu as? FolderContextMenu else { return }
        
        guard row != -1, let node = listView.outlineView.item(atRow: row) as? SidebarNode, node.type == .folder else {
            ctxMenu.removeAllItems(); return
        }
        
        listView.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        ctxMenu.update(target: self, renameAction: #selector(contextRenameTapped), deleteAction: #selector(contextDeleteTapped))
    }
}
