import AppKit

public final class NoteListView: NSView {
    public let searchField = SearchField()
    public let tableView = NSTableView()
    public let scrollView = NSScrollView()
    public let headerLabel = NSTextField(labelWithString: "All Notes")
    public let addNoteButton = NSButton()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
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
        
        titleStack.addArrangedSubview(headerLabel)
        titleStack.addArrangedSubview(NSView()) // spacer
        titleStack.addArrangedSubview(addNoteButton)
        
        // 2. Table View
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
        addSubview(titleStack)
        addSubview(searchField)
        addSubview(scrollView)
        
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleStack.heightAnchor.constraint(equalToConstant: 28),
            
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 10),
            
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
