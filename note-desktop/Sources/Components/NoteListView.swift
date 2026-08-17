import AppKit

public final class CustomNoteTableView: NSTableView {
    public var onEscapePressed: (() -> Void)?
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }
}

public final class NoteListView: NSView {
    public let searchField = SearchField()
    public let tableView = CustomNoteTableView()
    public let scrollView = NSScrollView()
    public let headerLabel = NSTextField(labelWithString: "All Notes")
    public let addNoteButton = NSButton()
    
    public let emptyStateLabel = NSTextField(labelWithString: "")
    
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
        
        // 1. Title Stack
        let titleStack = NSStackView()
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY
        titleStack.spacing = 8
        
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        headerLabel.textColor = .labelColor
        
        addNoteButton.isHidden = true
        
        titleStack.addArrangedSubview(headerLabel)
        titleStack.addArrangedSubview(NSView()) // spacer
        
        // 2. Table View
        tableView.headerView = nil
        tableView.rowHeight = 68
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NoteColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        
        // 3. Empty state label
        emptyStateLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.isHidden = true
        
        // Layout views
        addSubview(titleStack)
        addSubview(searchField)
        addSubview(scrollView)
        addSubview(emptyStateLabel)
        
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 2),
            titleStack.heightAnchor.constraint(equalToConstant: 28),
            
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 10),
            
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor, constant: -20),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }
}
