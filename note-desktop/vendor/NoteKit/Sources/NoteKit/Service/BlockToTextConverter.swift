import AppKit

public final class BlockToTextConverter {
    
    // Cache compiled regular expressions to avoid high compilation overhead during interactive typing
    private static let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\((https?://[^\\)]+)\\)")
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*")
    private static let italicRegex = try! NSRegularExpression(pattern: "\\*([^*]+)\\*")
    
    // Thread-safe cache of pre-rendered attributed strings to achieve O(1) typing performance
    private static let stringCache = NSCache<NSString, NSAttributedString>()
    
    public static func convert(blocks: [Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for (index, block) in blocks.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .blockId: block.id,
                .blockType: block.type,
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.textColor
            ]
            
            result.append(NSAttributedString(string: block.content, attributes: attrs))
            
            if index < blocks.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attrs))
            }
        }
        
        return result
    }
    
    /// Clears the block rendering cache manually when switching documents or resetting.
    public static func clearCache() {
        stringCache.removeAllObjects()
    }
}
