import AppKit

public final class TextToBlockConverter {
    
    public static func parseBlocks(from attributedString: NSAttributedString) -> [Block] {
        var blocks: [Block] = []
        let totalLength = attributedString.length
        
        if totalLength == 0 {
            return []
        }
        
        // Enumerate ranges where the blockId is identical
        attributedString.enumerateAttribute(.blockId, in: NSRange(location: 0, length: totalLength), options: []) { value, range, _ in
            guard let blockId = value as? UUID else { return }
            
            let blockSubString = attributedString.attributedSubstring(from: range)
            
            // Re-serialize the rich text attributes back to inline Markdown formatting
            let markdownContent = serializeToMarkdown(blockSubString)
            
            let type = attributedString.attribute(.blockType, at: range.location, effectiveRange: nil) as? BlockType ?? .text
            let isChecked = attributedString.attribute(.blockCheckedState, at: range.location, effectiveRange: nil) as? Bool
            
            let block = Block(id: blockId, type: type, content: markdownContent, isChecked: isChecked)
            blocks.append(block)
        }
        
        return blocks
    }
    
    private static func serializeToMarkdown(_ slice: NSAttributedString) -> String {
        var result = ""
        let length = slice.length
        
        slice.enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attrs, runRange, _ in
            let runString = slice.attributedSubstring(from: runRange).string
            
            // Skip separator newlines between blocks
            if runString == "\n" {
                return
            }
            
            var formattedRun = runString
            let font = attrs[.font] as? NSFont
            
            let isBold = font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
            let isItalic = font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
            let linkVal = attrs[.link]
            
            // Apply formatting tags
            if isBold {
                formattedRun = "**\(formattedRun)**"
            }
            if isItalic {
                formattedRun = "*\(formattedRun)*"
            }
            if let url = linkVal as? URL {
                formattedRun = "[\(formattedRun)](\(url.absoluteString))"
            } else if let urlStr = linkVal as? String {
                formattedRun = "[\(formattedRun)](\(urlStr))"
            }
            
            result += formattedRun
        }
        
        return result.trimmingCharacters(in: .newlines)
    }
}
