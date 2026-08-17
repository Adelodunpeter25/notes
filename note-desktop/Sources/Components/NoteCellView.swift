import AppKit

public final class NoteCellView: NSTableCellView {
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let pinImageView = NSImageView()
    
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
        // When row view is selected or emphasized, keep dark text on the yellow pill
        let isSelected = (backgroundStyle == .emphasized || (superview as? NSTableRowView)?.isSelected == true)
        if isSelected {
            titleLabel.textColor = .black
            subtitleLabel.textColor = NSColor.black.withAlphaComponent(0.75)
            pinImageView.contentTintColor = .black
        } else {
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .secondaryLabelColor
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
        
        pinImageView.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinImageView.imageScaling = .scaleProportionallyDown
        pinImageView.contentTintColor = AppColors.accent
        addSubview(pinImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinImageView.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            
            pinImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pinImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            pinImageView.widthAnchor.constraint(equalToConstant: 12),
            pinImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
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
