import AppKit

public final class InNoteSearchBar: NSView, NSSearchFieldDelegate {
    public let searchField = NSSearchField()
    public let prevButton = NSButton()
    public let nextButton = NSButton()
    public let matchCountLabel = NSTextField(labelWithString: "")
    public let doneButton = NSButton()
    
    public var onQueryChanged: ((String) -> Void)?
    public var onNextMatch: (() -> Void)?
    public var onPrevMatch: (() -> Void)?
    public var onClose: (() -> Void)?
    
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
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Search Field Setup
        searchField.placeholderString = "Find"
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        
        // Match Count Label
        matchCountLabel.font = NSFont.systemFont(ofSize: 11)
        matchCountLabel.textColor = .secondaryLabelColor
        matchCountLabel.alignment = .right
        
        // Prev/Next Navigation
        prevButton.isBordered = false
        prevButton.bezelStyle = .texturedRounded
        prevButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous")
        prevButton.imageScaling = .scaleProportionallyDown
        prevButton.target = self
        prevButton.action = #selector(prevTapped)
        
        nextButton.isBordered = false
        nextButton.bezelStyle = .texturedRounded
        nextButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")
        nextButton.imageScaling = .scaleProportionallyDown
        nextButton.target = self
        nextButton.action = #selector(nextTapped)
        
        // Segmented navigation container
        let navStack = NSStackView(views: [prevButton, nextButton])
        navStack.orientation = .horizontal
        navStack.spacing = 2
        navStack.alignment = .centerY
        
        // Done button
        doneButton.title = "Done"
        doneButton.bezelStyle = .recessed
        doneButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        doneButton.isBordered = true
        doneButton.target = self
        doneButton.action = #selector(doneTapped)
        
        let stack = NSStackView(views: [searchField, matchCountLabel, navStack, doneButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            prevButton.widthAnchor.constraint(equalToConstant: 18),
            prevButton.heightAnchor.constraint(equalToConstant: 18),
            nextButton.widthAnchor.constraint(equalToConstant: 18),
            nextButton.heightAnchor.constraint(equalToConstant: 18),
            doneButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    public func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }
    
    public func updateMatches(current: Int, total: Int) {
        if total == 0 {
            matchCountLabel.stringValue = searchField.stringValue.isEmpty ? "" : "No matches"
        } else {
            matchCountLabel.stringValue = "\(current) of \(total)"
        }
    }
    
    public func controlTextDidChange(_ obj: Notification) {
        onQueryChanged?(searchField.stringValue)
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onNextMatch?()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onClose?()
            return true
        }
        return false
    }
    
    @objc private func prevTapped() { onPrevMatch?() }
    @objc private func nextTapped() { onNextMatch?() }
    @objc private func doneTapped() { onClose?() }
}
