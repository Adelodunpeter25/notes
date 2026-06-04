import XCTest
@testable import NoteKit

final class ConverterCacheTests: XCTestCase {
    
    func testCacheInvalidationOnContentChange() {
        let blockId = UUID()
        let block = Block(id: blockId, type: .text, content: "Version A")
        
        let attrStringA = BlockToTextConverter.convert(blocks: [block])
        XCTAssertTrue(attrStringA.string.contains("Version A"))
        
        // Change the content of the block (which updates its content hash)
        let updatedBlock = Block(id: blockId, type: .text, content: "Version B")
        
        let attrStringB = BlockToTextConverter.convert(blocks: [updatedBlock])
        XCTAssertTrue(attrStringB.string.contains("Version B"))
        XCTAssertFalse(attrStringB.string.contains("Version A"))
    }
    
    func testCacheInvalidationOnTypeChange() {
        let blockId = UUID()
        let block = Block(id: blockId, type: .text, content: "Styled Text")
        
        let attrStringA = BlockToTextConverter.convert(blocks: [block])
        let fontA = attrStringA.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        
        // Change block type (from text to heading)
        let updatedBlock = Block(id: blockId, type: .heading, content: "Styled Text")
        let attrStringB = BlockToTextConverter.convert(blocks: [updatedBlock])
        let fontB = attrStringB.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        
        XCTAssertNotEqual(fontA?.pointSize, fontB?.pointSize)
        XCTAssertEqual(fontB?.pointSize, 22) // Heading font size is 22
    }
    
    func testCacheClear() {
        let block = Block(type: .text, content: "Clean Cache")
        let firstRender = BlockToTextConverter.convert(blocks: [block])
        
        BlockToTextConverter.clearCache()
        
        let secondRender = BlockToTextConverter.convert(blocks: [block])
        XCTAssertEqual(firstRender.string, secondRender.string)
    }
}
