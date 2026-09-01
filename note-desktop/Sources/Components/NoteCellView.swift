import AppKit

public final class NoteCellView: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let folderImageView = NSImageView()
    let folderLabel = NSTextField(labelWithString: "")
    let pinImageView = NSImageView()
    private var folderTopConstraint: NSLayoutConstraint!
    private var folderBottomConstraint: NSLayoutConstraint!
    private var subtitleBottomConstraint: NSLayoutConstraint!
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateColors()
        }
    }
    
    private func updateColors() {
        let isSelected = (backgroundStyle == .emphasized || (superview as? NSTableRowView)?.isSelected == true)
        if isSelected {
            titleLabel.textColor = .white
            subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.8)
            folderLabel.textColor = NSColor.white.withAlphaComponent(0.8)
            folderImageView.contentTintColor = .white
            pinImageView.contentTintColor = .white
        } else {
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .secondaryLabelColor
            folderLabel.textColor = .secondaryLabelColor
            folderImageView.contentTintColor = .secondaryLabelColor
            pinImageView.contentTintColor = AppColors.accent
        }
    }
    
    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateColors()
    }
    
    private func setupViews() {
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)
        
        folderImageView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        folderImageView.imageScaling = .scaleProportionallyDown
        folderImageView.contentTintColor = .secondaryLabelColor
        folderImageView.isHidden = true
        addSubview(folderImageView)
        
        folderLabel.font = NSFont.systemFont(ofSize: 11)
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.lineBreakMode = .byTruncatingTail
        folderLabel.isHidden = true
        addSubview(folderLabel)
        
        pinImageView.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinImageView.imageScaling = .scaleProportionallyDown
        pinImageView.contentTintColor = AppColors.accent
        addSubview(pinImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        folderImageView.translatesAutoresizingMaskIntoConstraints = false
        folderLabel.translatesAutoresizingMaskIntoConstraints = false
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        
        folderTopConstraint = folderImageView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 4)
        folderBottomConstraint = folderImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        subtitleBottomConstraint = subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        // Start with subtitle bottom active, folder constraints inactive when hidden
        subtitleBottomConstraint.priority = .defaultHigh
        folderTopConstraint.priority = .required
        folderBottomConstraint.priority = .required

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinImageView.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            folderImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            folderImageView.widthAnchor.constraint(equalToConstant: 12),
            folderImageView.heightAnchor.constraint(equalToConstant: 12),
            
            folderLabel.leadingAnchor.constraint(equalTo: folderImageView.trailingAnchor, constant: 4),
            folderLabel.centerYAnchor.constraint(equalTo: folderImageView.centerYAnchor),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            
            pinImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pinImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            pinImageView.widthAnchor.constraint(equalToConstant: 12),
            pinImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
        NSLayoutConstraint.activate([folderTopConstraint, folderBottomConstraint, subtitleBottomConstraint])
        updateFolderVisibility(false)
    }

    public func updateFolderVisibility(_ visible: Bool) {
        folderImageView.isHidden = !visible
        folderLabel.isHidden = !visible
        folderTopConstraint.isActive = visible
        folderBottomConstraint.isActive = visible
        subtitleBottomConstraint.isActive = !visible
    }
    
    public static func previewFromContent(_ content: String) -> String {
        let lines = NoteUtils.extractLines(from: content)
        if lines.count <= 1 {
            return "No additional text"
        }
        let remaining = lines.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if remaining.isEmpty {
            return "No additional text"
        }
        return remaining.joined(separator: " ")
    }
}
