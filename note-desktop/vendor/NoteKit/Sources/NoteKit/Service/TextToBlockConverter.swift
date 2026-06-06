import AppKit

public final class TextToBlockConverter {
    
    public static func parseBlocks(from attributedString: NSAttributedString) -> [Block] {
        var blocks: [Block] = []
        let totalLength = attributedString.length
        
        if totalLength == 0 {
            return []
        }
        
        var currentBlockId: UUID?
        var currentMarkdown = ""
        var currentType: BlockType = .text
        var currentIsChecked: Bool?
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: totalLength), options: []) { attrs, range, _ in
            let blockId = attrs[.blockId] as? UUID
            let type = attrs[.blockType] as? BlockType ?? .text
            let isChecked = attrs[.blockCheckedState] as? Bool
            
            let slice = attributedString.attributedSubstring(from: range)
            let markdown = serializeToMarkdown(slice)
            
            // AppKit inserts separator newlines between blocks that might not have the blockId attribute
            if slice.string == "\n" && blockId == nil {
                return
            }
            
            if let bid = blockId {
                if bid == currentBlockId {
                    currentMarkdown += markdown
                } else {
                    if let cid = currentBlockId {
                        blocks.append(Block(id: cid, type: currentType, content: currentMarkdown, isChecked: currentIsChecked))
                    }
                    currentBlockId = bid
                    currentMarkdown = markdown
                    currentType = type
                    currentIsChecked = isChecked
                }
            } else {
                // Fallback for typed text that lost its block ID attribute
                if currentBlockId == nil {
                    currentBlockId = UUID()
                }
                currentMarkdown += markdown
            }
        }
        
        if let cid = currentBlockId {
            blocks.append(Block(id: cid, type: currentType, content: currentMarkdown, isChecked: currentIsChecked))
        }
        
        return blocks
    }
    
    private static func serializeToMarkdown(_ slice: NSAttributedString) -> String {
        var result = ""
        let length = slice.length
        
        slice.enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attrs, runRange, _ in
            let runString = slice.attributedSubstring(from: runRange).string
            
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
        
        return result
    }
}
