import AppKit

public final class CustomEditorTextView: NSTextView {
    public var onEscapePressed: (() -> Void)?
    public var onFindPressed: (() -> Void)?
    public var onCheckboxClicked: ((Int) -> Void)?
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscapePressed?()
            return
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "f" {
            onFindPressed?()
            return
        }
        super.keyDown(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            super.mouseDown(with: event)
            return
        }
        
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        if charIndex < textStorage?.length ?? 0 {
            if let attr = textStorage?.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment,
               let cell = attr.attachmentCell as? CheckboxAttachmentCell {
                cell.isChecked.toggle()
                onCheckboxClicked?(charIndex)
                needsDisplay = true
                return
            }
        }
        super.mouseDown(with: event)
    }
}

public final class Editor: NSViewController, NSTextViewDelegate {
    private let noteService: NoteService
    private var activeNote: DBNote?
    private var isLoadingNote = false
    
    // UI Outlets
    private let headerLabel = NSTextField(labelWithString: "")
    private let toolbar = EditorToolbar()
    private let textView = CustomEditorTextView()
    private let scrollView = NSScrollView()
    public let searchBar = InNoteSearchBar()
    
    // Search State
    private var searchMatches: [NSRange] = []
    private var currentMatchIndex: Int = -1
    
    public var onNoteUpdated: ((DBNote?) -> Void)?
    public var onEscapePressed: (() -> Void)?
    
    public init(noteService: NoteService) {
        self.noteService = noteService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        textView.onEscapePressed = { [weak self] in
            if self?.searchBar.isHidden == false {
                self?.closeFindBar()
            } else {
                self?.onEscapePressed?()
            }
        }
        
        textView.onFindPressed = { [weak self] in
            self?.toggleFindBar()
        }
        
        textView.onCheckboxClicked = { [weak self] _ in
            self?.saveNoteContent()
        }
        
        // 1. Setup Header Date Display
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.font = NSFont.systemFont(ofSize: 11)
        headerLabel.alignment = .center
        
        // 2. Setup Plain Text Editor
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.linkTextAttributes = [
            .foregroundColor: AppColors.accent,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.delegate = self
        
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        
        scrollView.documentView = textView
        
        // 3. Search Bar Configuration
        searchBar.isHidden = true
        searchBar.onQueryChanged = { [weak self] query in
            self?.performSearch(query: query)
        }
        searchBar.onNextMatch = { [weak self] in
            self?.navigateMatch(forward: true)
        }
        searchBar.onPrevMatch = { [weak self] in
            self?.navigateMatch(forward: false)
        }
        searchBar.onClose = { [weak self] in
            self?.closeFindBar()
        }
        
        // Stack and align layouts
        let stack = NSStackView(views: [headerLabel, searchBar, scrollView])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .centerX
        stack.distribution = .fill
        
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            searchBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 28),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        updateEmptyStateVisibility()
    }
    
    private func updateEmptyStateVisibility() {
        let hasNote = (activeNote != nil)
        headerLabel.isHidden = !hasNote
        scrollView.isHidden = !hasNote
        if !hasNote {
            searchBar.isHidden = true
        }
    }
    
    // MARK: - Rich Text Formatting Actions (Available for Titlebar/Shortcuts)
    
    public func toggleBold() { toggleFontTrait(.boldFontMask) }
    public func toggleItalic() { toggleFontTrait(.italicFontMask) }
    public func toggleUnderline() {
        let range = textView.selectedRange()
        guard range.length > 0, let storage = textView.textStorage else { return }
        storage.beginEditing()
        let current = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
        let newStyle = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
        storage.addAttribute(.underlineStyle, value: newStyle, range: range)
        storage.endEditing()
        saveNoteContent()
    }
    public func toggleStrikethrough() {
        let range = textView.selectedRange()
        guard range.length > 0, let storage = textView.textStorage else { return }
        storage.beginEditing()
        let current = storage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
        let newStyle = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
        storage.addAttribute(.strikethroughStyle, value: newStyle, range: range)
        storage.endEditing()
        saveNoteContent()
    }
    public func applyTitle() { applyLineFormatting(fontSize: 22, weight: .bold) }
    public func applyHeading() { applyLineFormatting(fontSize: 18, weight: .semibold) }
    public func applySubheading() { applyLineFormatting(fontSize: 15, weight: .medium) }
    public func insertCheckbox() { insertCheckboxAtCurrentLine() }
    public func insertBulletList() { insertListPrefix("• ") }
    public func insertNumberedList() { insertListPrefix("1. ") }
    
    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        let range = textView.selectedRange()
        guard range.length > 0, let storage = textView.textStorage else { return }
        let fontManager = NSFontManager.shared
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            if let font = value as? NSFont {
                let newFont = fontManager.convert(font, toHaveTrait: trait)
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        storage.endEditing()
        saveNoteContent()
    }
    
    private func applyLineFormatting(fontSize: CGFloat, weight: NSFont.Weight) {
        let range = (textView.string as NSString).lineRange(for: textView.selectedRange())
        guard let storage = textView.textStorage else { return }
        storage.beginEditing()
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        storage.addAttribute(.font, value: font, range: range)
        storage.endEditing()
        saveNoteContent()
    }
    
    private func insertCheckboxAtCurrentLine() {
        let cell = CheckboxAttachmentCell()
        cell.isChecked = false
        let attachment = NSTextAttachment()
        attachment.attachmentCell = cell
        
        let attr = NSMutableAttributedString(attachment: attachment)
        attr.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.textColor]))
        
        let selectedRange = textView.selectedRange()
        textView.textStorage?.insert(attr, at: selectedRange.location)
        textView.setSelectedRange(NSRange(location: selectedRange.location + attr.length, length: 0))
        saveNoteContent()
    }
    
    private func insertListPrefix(_ prefix: String) {
        let selectedRange = textView.selectedRange()
        let attr = NSAttributedString(string: prefix, attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.textColor])
        textView.textStorage?.insert(attr, at: selectedRange.location)
        textView.setSelectedRange(NSRange(location: selectedRange.location + attr.length, length: 0))
        saveNoteContent()
    }
    
    // MARK: - Find / Search Bar Controls
    
    public func toggleFindBar() {
        guard activeNote != nil else { return }
        if searchBar.isHidden {
            searchBar.isHidden = false
            searchBar.focusSearchField()
            if !searchBar.searchField.stringValue.isEmpty {
                performSearch(query: searchBar.searchField.stringValue)
            }
        } else {
            searchBar.focusSearchField()
        }
    }
    
    public func closeFindBar() {
        searchBar.isHidden = true
        searchMatches.removeAll()
        currentMatchIndex = -1
        if activeNote != nil {
            textView.window?.makeFirstResponder(textView)
        }
        highlightMatches()
    }
    
    private func performSearch(query: String) {
        searchMatches.removeAll()
        currentMatchIndex = -1
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let text = textView.string as NSString? else {
            searchBar.updateMatches(current: 0, total: 0)
            highlightMatches()
            return
        }
        
        var range = NSRange(location: 0, length: text.length)
        while range.location < text.length {
            let found = text.range(of: trimmed, options: .caseInsensitive, range: range)
            if found.location != NSNotFound {
                searchMatches.append(found)
                range.location = found.location + max(found.length, 1)
                range.length = text.length - range.location
            } else {
                break
            }
        }
        
        if !searchMatches.isEmpty {
            currentMatchIndex = 0
            scrollToCurrentMatch()
        }
        
        searchBar.updateMatches(current: currentMatchIndex + 1, total: searchMatches.count)
        highlightMatches()
    }
    
    private func navigateMatch(forward: Bool) {
        guard !searchMatches.isEmpty else { return }
        if forward {
            currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        } else {
            currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        }
        scrollToCurrentMatch()
        searchBar.updateMatches(current: currentMatchIndex + 1, total: searchMatches.count)
        highlightMatches()
    }
    
    private func scrollToCurrentMatch() {
        guard currentMatchIndex >= 0 && currentMatchIndex < searchMatches.count else { return }
        let matchRange = searchMatches[currentMatchIndex]
        textView.scrollRangeToVisible(matchRange)
        textView.setSelectedRange(matchRange)
    }
    
    private func highlightMatches() {
        guard let storage = textView.textStorage else { return }
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
        
        for (idx, range) in searchMatches.enumerated() {
            if range.location + range.length <= storage.length {
                let color = (idx == currentMatchIndex) ? AppColors.accent.withAlphaComponent(0.6) : NSColor.systemYellow.withAlphaComponent(0.3)
                storage.addAttribute(.backgroundColor, value: color, range: range)
            }
        }
    }
    
    // MARK: - Note Loading & Rich Text Formatting
    
    /// Loads a specific database note inside the editor view.
    public func loadNote(_ note: DBNote?) {
        isLoadingNote = true
        defer { isLoadingNote = false }
        
        guard let note = note else {
            self.activeNote = nil
            headerLabel.stringValue = ""
            textView.string = ""
            closeFindBar()
            updateEmptyStateVisibility()
            return
        }
        
        if self.activeNote?.id == note.id {
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            updateEmptyStateVisibility()
            return
        }
        
        self.activeNote = note
        closeFindBar()
        updateEmptyStateVisibility()
        headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
        
        // Render rich text blocks (Option A)
        let blocks = AppFlowyConverter.toBlocks(jsonString: note.content)
        let attrString = renderAttributedContent(from: blocks)
        textView.textStorage?.setAttributedString(attrString)
        textView.checkTextInDocument(nil)
    }
    
    private func renderAttributedContent(from blocks: [Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for (index, block) in blocks.enumerated() {
            var font: NSFont = NSFont.systemFont(ofSize: 14)
            let textColor: NSColor = .textColor
            
            switch block.type {
            case .title:
                font = NSFont.systemFont(ofSize: 22, weight: .bold)
            case .heading:
                font = NSFont.systemFont(ofSize: 18, weight: .semibold)
            case .subheading:
                font = NSFont.systemFont(ofSize: 15, weight: .medium)
            case .todo:
                font = NSFont.systemFont(ofSize: 14)
                let cell = CheckboxAttachmentCell()
                cell.isChecked = block.isChecked ?? false
                let attachment = NSTextAttachment()
                attachment.attachmentCell = cell
                result.append(NSAttributedString(attachment: attachment))
                result.append(NSAttributedString(string: " "))
            case .bulletList, .dashedList:
                result.append(NSAttributedString(string: "• ", attributes: [.foregroundColor: AppColors.accent, .font: NSFont.systemFont(ofSize: 14, weight: .bold)]))
            case .numberedList:
                result.append(NSAttributedString(string: "\(index + 1). ", attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 14)]))
            default:
                break
            }
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            result.append(NSAttributedString(string: block.content, attributes: attrs))
            
            if index < blocks.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attrs))
            }
        }
        return result
    }
    
    private func saveNoteContent() {
        guard var note = activeNote else { return }
        
        // Convert text storage into blocks for AppFlowy cross-compatibility
        let rawString = textView.string
        let lines = rawString.components(separatedBy: .newlines)
        var blocks: [Block] = []
        
        var charOffset = 0
        for line in lines {
            var isChecked: Bool? = nil
            var blockType: BlockType = .text
            
            if let storage = textView.textStorage, charOffset < storage.length {
                if let attr = storage.attribute(.attachment, at: charOffset, effectiveRange: nil) as? NSTextAttachment,
                   let cell = attr.attachmentCell as? CheckboxAttachmentCell {
                    blockType = .todo
                    isChecked = cell.isChecked
                }
            }
            
            let cleanLine = line.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespaces)
            blocks.append(Block(type: blockType, content: cleanLine, isChecked: isChecked))
            charOffset += line.count + 1
        }
        
        if blocks.isEmpty {
            blocks = [Block(type: .text, content: "")]
        }
        
        let newJSON = AppFlowyConverter.toAppFlowyJSON(blocks: blocks)
        note.content = newJSON
        note.title = NoteUtils.titleFromContent(newJSON)
        
        if noteService.updateNote(note) {
            self.activeNote = note
            headerLabel.stringValue = TimeUtils.formatEditorHeader(for: note.updatedAt)
            onNoteUpdated?(note)
        }
    }
    
    // MARK: - NSTextViewDelegate
    
    public func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
            return true
        } else if let string = link as? String, let url = URL(string: string) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }
    
    public func textDidChange(_ notification: Notification) {
        guard !isLoadingNote else { return }
        saveNoteContent()
        if !searchBar.isHidden, !searchBar.searchField.stringValue.isEmpty {
            performSearch(query: searchBar.searchField.stringValue)
        }
    }
}

