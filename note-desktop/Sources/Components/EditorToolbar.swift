import AppKit

public protocol EditorToolbarDelegate: AnyObject {
    func toolbarDidTapPin(_ toolbar: EditorToolbar)
    func toolbarDidTapMove(_ toolbar: EditorToolbar)
    func toolbarDidTapDelete(_ toolbar: EditorToolbar)
    func toolbarDidTapCheckbox(_ toolbar: EditorToolbar)
}

public final class EditorToolbar: NSView {
    public weak var delegate: EditorToolbarDelegate?
    
    private let stackView = NSStackView()
    private let pinButton = NSButton()
    private let moveButton = NSButton()
    private let deleteButton = NSButton()
    private let todoButton = NSButton()
    
    public var isPinned = false {
        didSet {
            updatePinButton()
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 1. Insert Todo Checkbox button on the left
        configureButton(todoButton, iconName: "checkmark.square", action: #selector(todoTapped))
        stackView.addView(todoButton, in: .leading)
        
        // 2. Pin button on the right
        configureButton(pinButton, iconName: "pin", action: #selector(pinTapped))
        stackView.addView(pinButton, in: .trailing)
        
        // 3. Move folder button on the right
        configureButton(moveButton, iconName: "folder", action: #selector(moveTapped))
        stackView.addView(moveButton, in: .trailing)
        
        // 4. Delete button on the right
        configureButton(deleteButton, iconName: "trash", action: #selector(deleteTapped))
        stackView.addView(deleteButton, in: .trailing)
    }
    
    private func configureButton(_ button: NSButton, iconName: String, action: Selector) {
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func updatePinButton() {
        let iconName = isPinned ? "pin.fill" : "pin"
        pinButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    }
    
    @objc private func todoTapped() {
        delegate?.toolbarDidTapCheckbox(self)
    }
    
    @objc private func pinTapped() {
        delegate?.toolbarDidTapPin(self)
    }
    
    @objc private func moveTapped() {
        delegate?.toolbarDidTapMove(self)
    }
    
    @objc private func deleteTapped() {
        delegate?.toolbarDidTapDelete(self)
    }
}
