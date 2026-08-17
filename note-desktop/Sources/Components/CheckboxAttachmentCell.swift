import AppKit

public final class CheckboxAttachmentCell: NSTextAttachmentCell {
    public var isChecked: Bool = false
    public var onToggle: (() -> Void)?
    
    public override func cellSize() -> NSSize {
        return NSSize(width: 18, height: 18)
    }
    
    public override func cellBaselineOffset() -> NSPoint {
        return NSPoint(x: 0, y: -3)
    }
    
    public override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let boxRect = NSRect(x: cellFrame.origin.x + 1, y: cellFrame.origin.y + 1, width: 15, height: 15)
        let path = NSBezierPath(roundedRect: boxRect, xRadius: 3.5, yRadius: 3.5)
        
        if isChecked {
            AppColors.accent.setFill()
            path.fill()
            
            // Draw Checkmark
            let checkPath = NSBezierPath()
            checkPath.move(to: NSPoint(x: boxRect.minX + 3.5, y: boxRect.midY))
            checkPath.line(to: NSPoint(x: boxRect.minX + 6.0, y: boxRect.minY + 3.5))
            checkPath.line(to: NSPoint(x: boxRect.maxX - 3.5, y: boxRect.maxY - 4.0))
            checkPath.lineWidth = 1.8
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            NSColor.white.setStroke()
            checkPath.stroke()
        } else {
            NSColor.textBackgroundColor.setFill()
            path.fill()
            
            NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.2
            path.stroke()
        }
    }
}
