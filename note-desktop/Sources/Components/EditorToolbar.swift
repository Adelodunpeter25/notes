import AppKit

public final class EditorToolbar: NSView {
    public var onBold: (() -> Void)?
    public var onItalic: (() -> Void)?
    public var onUnderline: (() -> Void)?
    public var onStrikethrough: (() -> Void)?
    public var onTitle: (() -> Void)?
    public var onHeading: (() -> Void)?
    public var onSubheading: (() -> Void)?
    public var onCheckbox: (() -> Void)?
    public var onBulletList: (() -> Void)?
    public var onNumberedList: (() -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        layer?.cornerRadius = 6
        
        let boldBtn = createButton(symbol: "bold", tooltip: "Bold (⌘B)", action: #selector(boldTapped))
        let italicBtn = createButton(symbol: "italic", tooltip: "Italic (⌘I)", action: #selector(italicTapped))
        let underlineBtn = createButton(symbol: "underline", tooltip: "Underline (⌘U)", action: #selector(underlineTapped))
        let strikeBtn = createButton(symbol: "strikethrough", tooltip: "Strikethrough", action: #selector(strikeTapped))
        
        let div1 = createDivider()
        
        let titleBtn = createTextButton(title: "Title", tooltip: "Title", action: #selector(titleTapped))
        let headingBtn = createTextButton(title: "Heading", tooltip: "Heading", action: #selector(headingTapped))
        let subBtn = createTextButton(title: "Subheading", tooltip: "Subheading", action: #selector(subTapped))
        
        let div2 = createDivider()
        
        let todoBtn = createButton(symbol: "checkmark.square", tooltip: "To-do Checkbox", action: #selector(todoTapped))
        let bulletBtn = createButton(symbol: "list.bullet", tooltip: "Bullet List", action: #selector(bulletTapped))
        let numberBtn = createButton(symbol: "list.number", tooltip: "Numbered List", action: #selector(numberTapped))
        
        let stack = NSStackView(views: [
            boldBtn, italicBtn, underlineBtn, strikeBtn,
            div1,
            titleBtn, headingBtn, subBtn,
            div2,
            todoBtn, bulletBtn, numberBtn
        ])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func createButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        btn.bezelStyle = .texturedRounded
        btn.imagePosition = .imageOnly
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        btn.toolTip = tooltip
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }
    
    private func createTextButton(title: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        btn.bezelStyle = .texturedRounded
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        btn.toolTip = tooltip
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }
    
    private func createDivider() -> NSView {
        let div = NSView()
        div.wantsLayer = true
        div.layer?.backgroundColor = NSColor.separatorColor.cgColor
        div.translatesAutoresizingMaskIntoConstraints = false
        div.widthAnchor.constraint(equalToConstant: 1).isActive = true
        div.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return div
    }
    
    @objc private func boldTapped() { onBold?() }
    @objc private func italicTapped() { onItalic?() }
    @objc private func underlineTapped() { onUnderline?() }
    @objc private func strikeTapped() { onStrikethrough?() }
    @objc private func titleTapped() { onTitle?() }
    @objc private func headingTapped() { onHeading?() }
    @objc private func subTapped() { onSubheading?() }
    @objc private func todoTapped() { onCheckbox?() }
    @objc private func bulletTapped() { onBulletList?() }
    @objc private func numberTapped() { onNumberedList?() }
}
