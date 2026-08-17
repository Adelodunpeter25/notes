import AppKit

public final class FolderListView: NSView {
    public let outlineView = NSOutlineView()
    public let scrollView = NSScrollView()
    public let bottomBar = NSView()
    public let newFolderButton = NSButton()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Setup Outline View
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
        
        // 2. Setup Bottom Bar
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        newFolderButton.isBordered = false
        newFolderButton.title = "New Folder"
        newFolderButton.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        newFolderButton.imagePosition = .imageLeft
        newFolderButton.contentTintColor = AppColors.accent
        newFolderButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        bottomBar.addSubview(newFolderButton)
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newFolderButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            newFolderButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            newFolderButton.trailingAnchor.constraint(lessThanOrEqualTo: bottomBar.trailingAnchor, constant: -16)
        ])
        
        addSubview(scrollView)
        addSubview(bottomBar)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}
