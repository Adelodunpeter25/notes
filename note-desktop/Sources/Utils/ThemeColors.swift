import AppKit

public struct AppColors {
    // Accent Color
    public static let accent = NSColor(red: 0xD4/255.0, green: 0xA0/255.0, blue: 0x17/255.0, alpha: 1.0)
    
    // Core Palette
    public static let destructive = NSColor(red: 0xFF/255.0, green: 0x3B/255.0, blue: 0x30/255.0, alpha: 1.0)
    public static let success = NSColor(red: 0x34/255.0, green: 0xC7/255.0, blue: 0x59/255.0, alpha: 1.0)
    public static let handle = NSColor(red: 0xBD/255.0, green: 0xBD/255.0, blue: 0xBD/255.0, alpha: 1.0)
    
    // Dark Theme Colors
    public static let darkBg = NSColor(red: 0x00/255.0, green: 0x00/255.0, blue: 0x00/255.0, alpha: 1.0)
    public static let darkSurface = NSColor(red: 0x1C/255.0, green: 0x1C/255.0, blue: 0x1E/255.0, alpha: 1.0)
    public static let darkElevated = NSColor(red: 0x2C/255.0, green: 0x2C/255.0, blue: 0x2E/255.0, alpha: 1.0)
    
    // Light Theme Colors
    public static let lightBg = NSColor(red: 0xF2/255.0, green: 0xF2/255.0, blue: 0xF7/255.0, alpha: 1.0)
    public static let lightSurface = NSColor.white
    public static let lightElevated = NSColor(red: 0xE5/255.0, green: 0xE5/255.0, blue: 0xEA/255.0, alpha: 1.0)
    
    // Semantic Resolution
    public static func background(isDark: Bool) -> NSColor {
        return isDark ? darkBg : lightBg
    }
    
    public static func surface(isDark: Bool) -> NSColor {
        return isDark ? darkSurface : lightSurface
    }
    
    public static func elevated(isDark: Bool) -> NSColor {
        return isDark ? darkElevated : lightElevated
    }
    
    public static func divider(isDark: Bool) -> NSColor {
        return isDark ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.12)
    }
}

public final class ThemeTableRowView: NSTableRowView {
    public override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 10, dy: 2)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 8, yRadius: 8)
            AppColors.accent.setFill()
            path.fill()
        }
    }
}

public final class FolderTableRowView: NSTableRowView {
    public override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 6, dy: 1)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            let highlightColor = NSColor(white: 1.0, alpha: 0.10)
            highlightColor.setFill()
            path.fill()
        }
    }
}
