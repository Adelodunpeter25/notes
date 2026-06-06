import AppKit

public final class TextToBlockConverter {
    
    public static func parseBlocks(from attributedString: NSAttributedString) -> [Block] {
        let totalLength = attributedString.length
        
        if totalLength == 0 {
            return []
        }
        
        // Treat the entire document as a single text block for now to ensure functionality
        let content = attributedString.string
        let blockId = attributedString.attribute(.blockId, at: 0, effectiveRange: nil) as? UUID ?? UUID()
        
        return [Block(id: blockId, type: .text, content: content, isChecked: nil)]
    }
}
