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

public final class FolderList: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    // MARK: - Sidebar Item Representation
    private final class SidebarNode: NSObject {
        let type: NodeType
        let name: String
        let folder: DBFolder?
        let children: [SidebarNode]
        
        enum NodeType {
            case header
            case allNotes
            case folder
            case trash
        }
        
        init(type: NodeType, name: String, folder: DBFolder? = nil, children: [SidebarNode] = []) {
            self.type = type
            self.name = name
            self.folder = folder
            self.children = children
        }
    }
    
    // MARK: - Properties
    private let storage: StorageService
    private let folderService: FolderService
    private let userId: String
    
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
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
        
        // 1. Sidebar Header / Title + Button Stack
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        
        let titleLabel = NSTextField(labelWithString: "NOTES")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .secondaryLabelColor
        
        let addButton = NSButton()
        addButton.isBordered = false
        addButton.imagePosition = .imageOnly
        addButton.bezelStyle = .texturedRounded
        addButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Add Folder")
        addButton.target = self
        addButton.action = #selector(addFolderTapped)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(NSView()) // spacer
        headerStack.addArrangedSubview(addButton)
        
        // 2. Setup Outline View
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        if #available(macOS 12.0, *) {
            outlineView.style = .sourceList
        } else {
            outlineView.selectionHighlightStyle = .sourceList
        }
        outlineView.floatsGroupRows = false
        outlineView.rowHeight = 28
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = outlineView
        
        // Add layouts
        view.addSubview(headerStack)
        view.addSubview(scrollView)
        
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerStack.heightAnchor.constraint(equalToConstant: 28),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Context menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Rename Folder", action: #selector(contextRenameTapped), keyEquivalent: "")
        menu.addItem(withTitle: "Delete Folder", action: #selector(contextDeleteTapped), keyEquivalent: "")
        outlineView.menu = menu
    }
    
    // MARK: - Data Management
    public func reloadData() {
        let activeFolders = storage.listActiveFolders(userId: userId)
        
        let libraryNode = SidebarNode(type: .header, name: "LIBRARY", children: [
            SidebarNode(type: .allNotes, name: "All Notes")
        ])
        
        let folderNodes = activeFolders.map {
            SidebarNode(type: .folder, name: $0.name, folder: $0)
        }
        let foldersHeader = SidebarNode(type: .header, name: "FOLDERS", children: folderNodes)
        
        let trashNode = SidebarNode(type: .header, name: "TRASH", children: [
            SidebarNode(type: .trash, name: "Trash")
        ])
        
        self.data = [libraryNode, foldersHeader, trashNode]
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
    @objc private func addFolderTapped() {
        RenameDialog.show(
            title: "New Folder",
            message: "Enter the name for your new folder:",
            initialValue: "",
            placeholder: "Folder Name"
        ) { [weak self] name in
            guard let self = self else { return }
            if let folder = self.folderService.createFolder(name: name, userId: self.userId) {
                self.reloadData()
                // Select the new folder
                self.selectFolder(folder)
            }
        }
    }
    
    private func selectFolder(_ folder: DBFolder) {
        for header in data {
            for child in header.children {
                if child.folder?.id == folder.id {
                    let row = outlineView.row(forItem: child)
                    if row != -1 {
                        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    }
                    return
                }
            }
        }
    }
    
    @objc private func contextRenameTapped() {
        let clickedRow = outlineView.clickedRow
        guard clickedRow != -1,
              let node = outlineView.item(atRow: clickedRow) as? SidebarNode,
              node.type == .folder,
              let folder = node.folder else { return }
        
        RenameDialog.show(
            title: "Rename Folder",
            message: "Enter new name for the folder:",
            initialValue: folder.name,
            placeholder: "Folder Name"
        ) { [weak self] newName in
            guard let self = self else { return }
            if self.folderService.renameFolder(folder, newName: newName) {
                self.reloadData()
            }
        }
    }
    
    @objc private func contextDeleteTapped() {
        let clickedRow = outlineView.clickedRow
        guard clickedRow != -1,
              let node = outlineView.item(atRow: clickedRow) as? SidebarNode,
              node.type == .folder,
              let folder = node.folder else { return }
        
        ConfirmDialog.show(
            title: "Delete Folder",
            message: "Are you sure you want to delete the folder '\(folder.name)'? Notes inside will be moved to active storage.",
            actionTitle: "Delete"
        ) { [weak self] in
            guard let self = self else { return }
            if self.folderService.softDeleteFolder(folder) {
                self.reloadData()
                self.onSelectionChanged?(.allNotes)
            }
        }
    }
    
    // MARK: - NSOutlineViewDataSource
    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return data.count
        } else if let node = item as? SidebarNode {
            return node.children.count
        }
        return 0
    }
    
    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return data[index]
        } else if let node = item as? SidebarNode {
            return node.children[index]
        }
        fatalError("Invalid node hierarchy index requested")
    }
    
    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        return !node.children.isEmpty
    }
    
    // MARK: - NSOutlineViewDelegate
    public func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        return node.type == .header
    }
    
    public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        return node.type != .header
    }
    
    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        
        if node.type == .header {
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
            view.stringValue = node.name
            view.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            view.textColor = .secondaryLabelColor
            view.identifier = NSUserInterfaceItemIdentifier("HeaderCell")
            return view
        }
        
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SidebarCell"), owner: self) as? SidebarCellView ?? SidebarCellView(frame: .zero)
        cell.identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        cell.textField?.stringValue = node.name
        
        let iconName: String
        switch node.type {
        case .allNotes:
            iconName = "tray"
        case .folder:
            iconName = "folder"
        case .trash:
            iconName = "trash"
        default:
            iconName = "folder"
        }
        
        cell.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        let count = getCount(for: node)
        cell.badgeField.stringValue = count > 0 ? "\(count)" : ""
        
        return cell
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
    let badgeField = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyDown
        self.imageView = iconView
        addSubview(iconView)
        
        let titleField = NSTextField(labelWithString: "")
        titleField.lineBreakMode = .byTruncatingTail
        titleField.font = NSFont.systemFont(ofSize: 12)
        titleField.textColor = .labelColor
        self.textField = titleField
        addSubview(titleField)
        
        badgeField.textColor = .secondaryLabelColor
        badgeField.font = NSFont.systemFont(ofSize: 11)
        badgeField.alignment = .right
        addSubview(badgeField)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleField.translatesAutoresizingMaskIntoConstraints = false
        badgeField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: badgeField.leadingAnchor, constant: -8),
            
            badgeField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            badgeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeField.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }
}
