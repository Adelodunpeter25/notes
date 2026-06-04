import XCTest
@testable import NoteKit

final class NoteKitTests: XCTestCase {
    
    func testBlockToTextConversion() throws {
        let blockId1 = UUID()
        let blockId2 = UUID()
        
        let blocks = [
            Block(id: blockId1, type: .title, content: "My Awesome Note"),
            Block(id: blockId2, type: .todo, content: "Finish task", isChecked: true)
        ]
        
        let attrString = BlockToTextConverter.convert(blocks: blocks)
        
        XCTAssertGreaterThan(attrString.length, 0)
        
        // Find attributes of the first block
        let id1 = attrString.attribute(.blockId, at: 0, effectiveRange: nil) as? UUID
        let type1 = attrString.attribute(.blockType, at: 0, effectiveRange: nil) as? BlockType
        
        XCTAssertEqual(id1, blockId1)
        XCTAssertEqual(type1, .title)
        
        // Find attributes of the second block (towards the end of the string)
        let lastIndex = attrString.length - 1
        let id2 = attrString.attribute(.blockId, at: lastIndex, effectiveRange: nil) as? UUID
        let type2 = attrString.attribute(.blockType, at: lastIndex, effectiveRange: nil) as? BlockType
        let isChecked2 = attrString.attribute(.blockCheckedState, at: lastIndex, effectiveRange: nil) as? Bool
        
        XCTAssertEqual(id2, blockId2)
        XCTAssertEqual(type2, .todo)
        XCTAssertEqual(isChecked2, true)
    }
    
    func testInlineMarkdownParsing() throws {
        let text = "This is **bold** text and *italic* styling with a [Google](https://google.com) link."
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .blockId: UUID(),
            .blockType: BlockType.text
        ]
        
        let parsed = BlockToTextConverter.parseInlineMarkdown(text, baseAttributes: baseAttrs)
        
        // The markdown characters (**, *, [], ()) should have been stripped out in output representation
        XCTAssertFalse(parsed.string.contains("**"))
        XCTAssertFalse(parsed.string.contains("[Google]"))
        
        // Verify link attribute was added
        var foundLink = false
        parsed.enumerateAttribute(.link, in: NSRange(location: 0, length: parsed.length), options: []) { value, range, _ in
            if let url = value as? URL {
                XCTAssertEqual(url.absoluteString, "https://google.com")
                let linkText = parsed.attributedSubstring(from: range).string
                XCTAssertEqual(linkText, "Google")
                foundLink = true
            }
        }
        XCTAssertTrue(foundLink)
    }
    
    func testTextToBlockSerialization() throws {
        let blockId = UUID()
        let originalContent = "This is **bold** and *italic* and [Apple](https://apple.com) link."
        
        let block = Block(id: blockId, type: .text, content: originalContent)
        
        // Convert to attributed string
        let attrString = BlockToTextConverter.convert(blocks: [block])
        
        // Parse back to blocks
        let parsedBlocks = TextToBlockConverter.parseBlocks(from: attrString)
        
        XCTAssertEqual(parsedBlocks.count, 1)
        XCTAssertEqual(parsedBlocks[0].id, blockId)
        XCTAssertEqual(parsedBlocks[0].type, .text)
        XCTAssertEqual(parsedBlocks[0].content, originalContent)
    }
}
