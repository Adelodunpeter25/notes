import AppKit

public final class SearchField: NSSearchField {
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        placeholderString = "Search notes"
        bezelStyle = .roundedBezel
        focusRingType = .none
        sendsWholeSearchString = false
        sendsSearchStringImmediately = true
        font = NSFont.systemFont(ofSize: 13)
        wantsLayer = true
    }
}
