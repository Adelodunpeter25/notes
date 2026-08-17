import AppKit

public final class SidebarCellView: NSTableCellView {
    public let iconView = NSImageView()
    public let nameField = NSTextField()
    public let badgeField = NSTextField(labelWithString: "")
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            nameField.textColor = .labelColor
            badgeField.textColor = .secondaryLabelColor
            iconView.contentTintColor = AppColors.accent
        }
    }
    
    private func setupViews() {
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = AppColors.accent
        addSubview(iconView)
        
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.isEditable = false
        nameField.isSelectable = false
        nameField.font = NSFont.systemFont(ofSize: 14)
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
