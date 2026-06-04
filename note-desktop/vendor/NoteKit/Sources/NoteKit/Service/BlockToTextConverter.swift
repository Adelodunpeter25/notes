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
            // Generate a composite key representing the exact state of this block
            let cacheKey = "\(block.id.uuidString)-\(block.type.rawValue)-\(block.isChecked ?? false)-\(block.content.hashValue)" as NSString
            
            let blockContent: NSAttributedString
            if let cached = stringCache.object(forKey: cacheKey) {
                blockContent = cached
            } else {
                let baseAttributes = buildBlockAttributes(for: block)
                let rendered = parseInlineMarkdown(block.content, baseAttributes: baseAttributes)
                stringCache.setObject(rendered, forKey: cacheKey)
                blockContent = rendered
            }
            
            result.append(blockContent)
            
            // Add a paragraph break between blocks (except for the last one)
            if index < blocks.count - 1 {
                let newlineAttrs: [NSAttributedString.Key: Any] = [
                    .blockId: block.id,
                    .blockType: block.type
                ]
                result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
            }
        }
        
        return result
    }
    
    /// Clears the block rendering cache manually when switching documents or resetting.
    public static func clearCache() {
        stringCache.removeAllObjects()
    }
    
    private static func buildBlockAttributes(for block: Block) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .blockId: block.id,
            .blockType: block.type
        ]
        
        let font: NSFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        switch block.type {
        case .title:
            font = NSFont.boldSystemFont(ofSize: 28)
            paragraphStyle.paragraphSpacing = 16
        case .heading:
            font = NSFont.boldSystemFont(ofSize: 22)
            paragraphStyle.paragraphSpacing = 12
        case .subheading:
            font = NSFont.boldSystemFont(ofSize: 18)
            paragraphStyle.paragraphSpacing = 8
        case .text:
            font = NSFont.systemFont(ofSize: 14)
            paragraphStyle.paragraphSpacing = 8
        case .bulletList, .numberedList, .dashedList:
            font = NSFont.systemFont(ofSize: 14)
            paragraphStyle.paragraphSpacing = 4
            paragraphStyle.headIndent = 24
            paragraphStyle.firstLineHeadIndent = 12
        case .todo:
            font = NSFont.systemFont(ofSize: 14)
            paragraphStyle.paragraphSpacing = 6
            paragraphStyle.headIndent = 24
            paragraphStyle.firstLineHeadIndent = 12
            attrs[.blockCheckedState] = block.isChecked ?? false
        }
        
        attrs[.font] = font
        attrs[.paragraphStyle] = paragraphStyle
        
        // Define default text color for dark mode UI
        attrs[.foregroundColor] = NSColor.textColor
        
        return attrs
    }
    
    /// Parses inline markdown tags (**bold**, *italic*, [text](url)) and converts them to rich text attributes,
    /// removing the markdown syntax tokens from the final rendered text.
    public static func parseInlineMarkdown(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let baseFont = baseAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
        
        // 1. Links: [label](url)
        parseLinks(result)
        
        // 2. Bold: **text**
        parseBold(result, baseFont: baseFont)
        
        // 3. Italic: *text* or _text_
        parseItalic(result, baseFont: baseFont)
        
        return result
    }
    
    private static func parseLinks(_ result: NSMutableAttributedString) {
        var offset = 0
        let matches = linkRegex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
        
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let labelRange = NSRange(location: match.range(at: 1).location + offset, length: match.range(at: 1).length)
            let urlRange = NSRange(location: match.range(at: 2).location + offset, length: match.range(at: 2).length)
            
            let urlString = result.attributedSubstring(from: urlRange).string
            
            if let url = URL(string: urlString) {
                let replacement = NSMutableAttributedString(attributedString: result.attributedSubstring(from: labelRange))
                replacement.addAttribute(.link, value: url, range: NSRange(location: 0, length: replacement.length))
                // Add underline styling
                replacement.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: replacement.length))
                
                result.replaceCharacters(in: adjustedRange, with: replacement)
                offset += replacement.length - match.range.length
            }
        }
    }
    
    private static func parseBold(_ result: NSMutableAttributedString, baseFont: NSFont) {
        var offset = 0
        let matches = boldRegex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
        
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let contentRange = NSRange(location: match.range(at: 1).location + offset, length: match.range(at: 1).length)
            
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            let replacement = NSMutableAttributedString(attributedString: result.attributedSubstring(from: contentRange))
            replacement.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: replacement.length))
            
            result.replaceCharacters(in: adjustedRange, with: replacement)
            offset += replacement.length - match.range.length
        }
    }
    
    private static func parseItalic(_ result: NSMutableAttributedString, baseFont: NSFont) {
        var offset = 0
        let matches = italicRegex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
        
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let contentRange = NSRange(location: match.range(at: 1).location + offset, length: match.range(at: 1).length)
            
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            let replacement = NSMutableAttributedString(attributedString: result.attributedSubstring(from: contentRange))
            replacement.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: replacement.length))
            
            result.replaceCharacters(in: adjustedRange, with: replacement)
            offset += replacement.length - match.range.length
        }
    }
}
