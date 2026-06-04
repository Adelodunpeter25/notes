import AppKit

public enum FolderSelection: Equatable {
    public static func == (lhs: FolderSelection, rhs: FolderSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allNotes, .allNotes):
            return true
        case (.trash, .trash):
            return true
        case (.folder(let lFolder), .folder(let rFolder)):
            return lFolder.id == rFolder.id && lFolder.name == rFolder.name
        default:
            return false
        }
    }

    case allNotes
    case folder(DBFolder)
    case trash
}

public final class FolderList: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate {
    
    // MARK: - Sidebar Item Representation
    private final class SidebarNode: NSObject {
        let type: NodeType
        var name: String
        var folder: DBFolder?
        
        enum NodeType {
            case allNotes
            case folder
            case divider
            case trash
        }
        
        init(type: NodeType, name: String, folder: DBFolder? = nil) {
            self.type = type
            self.name = name
            self.folder = folder
        }
    }
    
    // MARK: - Properties
    private let storage: StorageService
    private let folderService: FolderService
    private let userId: String
    
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let bottomBar = NSView()
    private let newFolderButton = NSButton()
    
    private var data: [SidebarNode] = []
    
    public var onSelectionChanged: ((FolderSelection) -> Void)?
    
    // MARK: - Initializer
    public init(storage: StorageService, folderService: FolderService, userId: String) {
        self.storage = storage
        self.folderService = folderService
        self.userId = userId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 600))
        setupUI()
        reloadData()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Setup Outline View
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.floatsGroupRows = false
        outlineView.rowHeight = 28
        
        if #available(macOS 12.0, *) {
            outlineView.style = .sourceList
        } else {
            outlineView.selectionHighlightStyle = .sourceList
        }
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = outlineView
        
        // 2. Setup Bottom "New Folder" Bar
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        newFolderButton.isBordered = false
        newFolderButton.title = "New Folder"
        newFolderButton.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        newFolderButton.imagePosition = .imageLeft
        newFolderButton.contentTintColor = AppColors.accent
        newFolderButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonTapped)
        
        bottomBar.addSubview(newFolderButton)
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newFolderButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            newFolderButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            newFolderButton.trailingAnchor.constraint(lessThanOrEqualTo: bottomBar.trailingAnchor, constant: -16)
        ])
        
        // Add layouts
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Data Management
    public func reloadData() {
        let activeFolders = storage.listActiveFolders(userId: userId)
        
        var nodes: [SidebarNode] = []
        nodes.append(SidebarNode(type: .allNotes, name: "All Notes"))
        
        for folder in activeFolders {
            nodes.append(SidebarNode(type: .folder, name: folder.name, folder: folder))
        }
        
        nodes.append(SidebarNode(type: .divider, name: ""))
        nodes.append(SidebarNode(type: .trash, name: "Trash"))
        
        self.data = nodes
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }
    
    private func getCount(for node: SidebarNode) -> Int {
        switch node.type {
        case .allNotes:
            return storage.listActiveNotes(userId: userId).count
        case .folder:
            guard let folder = node.folder else { return 0 }
            return storage.listNotesInFolder(userId: userId, folderId: folder.id).count
        case .trash:
            return storage.listTrashNotes(userId: userId).count
        default:
            return 0
        }
    }
    
    // MARK: - Actions
    @objc private func newFolderButtonTapped() {
        if let folder = folderService.createFolder(name: "Untitled Folder", userId: userId) {
            reloadData()
            selectFolder(folder)
            
            // Initiate inline editing immediately on the new folder row
            DispatchQueue.main.async { [weak self] in
                self?.contextRenameTapped()
            }
        }
    }
    
    private func selectFolder(_ folder: DBFolder) {
        for node in data {
            if node.folder?.id == folder.id {
                let row = outlineView.row(forItem: node)
                if row != -1 {
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                }
                return
            }
        }
    }
    
    @objc private func contextRenameTapped() {
        let row = outlineView.selectedRow
        guard row != -1,
              let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SidebarCellView,
              let node = outlineView.item(atRow: row) as? SidebarNode,
              node.type == SidebarNode.NodeType.folder else { return }
        
        cell.nameField.isEditable = true
        cell.nameField.isEnabled = true
        outlineView.window?.makeFirstResponder(cell.nameField)
        cell.nameField.currentEditor()?.selectAll(nil)
    }
    
    @objc private func contextDeleteTapped() {
        let row = outlineView.selectedRow
        guard row != -1,
              let node = outlineView.item(atRow: row) as? SidebarNode,
              node.type == SidebarNode.NodeType.folder,
              let folder = node.folder else { return }
        
        ConfirmDialog.show(
            title: "Delete Folder",
            message: "Are you sure you want to delete the folder '\(folder.name)'? Notes inside will be moved to active storage.",
            actionTitle: "Delete"
        ) { [weak self] in
            guard let self = self else { return }
            if self.folderService.deleteFolder(folder) {
                self.reloadData()
                self.onSelectionChanged?(.allNotes)
            }
        }
    }
    
    // MARK: - NSTextFieldDelegate
    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let row = outlineView.row(for: textField)
        guard row != -1,
              let node = outlineView.item(atRow: row) as? SidebarNode,
              node.type == SidebarNode.NodeType.folder,
              let folder = node.folder else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty && newName != folder.name {
            if folderService.renameFolder(folder, newName: newName) {
                node.folder?.name = newName
                reloadData()
            }
        } else {
            textField.stringValue = folder.name
        }
        textField.isEditable = false
    }
    
    // MARK: - NSOutlineViewDataSource
    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return data.count
        }
        return 0
    }
    
    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return data[index]
        }
        fatalError("No nested children allowed in flat sidebar design")
    }
    
    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    // MARK: - NSOutlineViewDelegate
    public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        return node.type != SidebarNode.NodeType.divider
    }
    
    public func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let node = item as? SidebarNode else { return 28 }
        if node.type == SidebarNode.NodeType.divider {
            return 12
        }
        return 28
    }
    
    public func outlineView(_ outlineView: NSOutlineView, menuFor item: Any?) -> NSMenu? {
        guard let node = item as? SidebarNode else { return nil }
        if node.type == SidebarNode.NodeType.folder {
            return FolderContextMenu(target: self, renameAction: #selector(contextRenameTapped), deleteAction: #selector(contextDeleteTapped))
        }
        return nil
    }
    
    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        
        if node.type == SidebarNode.NodeType.divider {
            let container = NSView()
            let line = NSView()
            line.wantsLayer = true
            let isDark = outlineView.effectiveAppearance.name.rawValue.contains("Dark")
            line.layer?.backgroundColor = AppColors.divider(isDark: isDark).cgColor
            
            container.addSubview(line)
            line.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                line.heightAnchor.constraint(equalToConstant: 1)
            ])
            return container
        }
        
        var cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SidebarCell"), owner: self) as? SidebarCellView
        if cell == nil {
            cell = SidebarCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        }
        
        cell?.nameField.stringValue = node.name
        cell?.nameField.delegate = self
        
        let iconName: String
        switch node.type {
        case SidebarNode.NodeType.allNotes:
            iconName = "folder"
        case SidebarNode.NodeType.folder:
            iconName = "folder"
        case SidebarNode.NodeType.trash:
            iconName = "trash"
        default:
            iconName = "folder"
        }
        
        cell?.iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        let count = getCount(for: node)
        cell?.badgeField.stringValue = count > 0 ? "\(count)" : ""
        
        return cell
    }
    
    public func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        var rowView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ThemeRowView"), owner: self) as? ThemeTableRowView
        if rowView == nil {
            rowView = ThemeTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier("ThemeRowView")
        }
        return rowView
    }
    
    public func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = outlineView.selectedRow
        guard selectedRow != -1,
              let node = outlineView.item(atRow: selectedRow) as? SidebarNode else { return }
        
        switch node.type {
        case .allNotes:
            onSelectionChanged?(.allNotes)
        case .folder:
            if let folder = node.folder {
                onSelectionChanged?(.folder(folder))
            }
        case .trash:
            onSelectionChanged?(.trash)
        default:
            break
        }
    }
}

// MARK: - Sidebar Cell View
fileprivate final class SidebarCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameField = NSTextField()
    let badgeField = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = AppColors.accent
        addSubview(iconView)
        
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.isEditable = false
        nameField.isSelectable = true
        nameField.font = NSFont.systemFont(ofSize: 12)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        self.textField = nameField
        addSubview(nameField)
        
        badgeField.textColor = .secondaryLabelColor
        badgeField.font = NSFont.systemFont(ofSize: 11)
        badgeField.alignment = .right
        addSubview(badgeField)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        nameField.translatesAutoresizingMaskIntoConstraints = false
        badgeField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameField.trailingAnchor.constraint(lessThanOrEqualTo: badgeField.leadingAnchor, constant: -8),
            
            badgeField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            badgeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeField.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }
}
