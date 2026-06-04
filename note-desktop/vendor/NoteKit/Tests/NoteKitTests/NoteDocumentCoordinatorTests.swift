import XCTest
@testable import NoteKit

final class NoteDocumentCoordinatorTests: XCTestCase {
    
    func testCoordinatorBidirectionalSync() throws {
        let blockId = UUID()
        let store = BlockStore(blocks: [
            Block(id: blockId, type: .text, content: "Initial Text")
        ])
        
        let textContentStorage = NSTextContentStorage()
        let coordinator = NoteDocumentCoordinator(store: store, textContentStorage: textContentStorage)
        
        // 1. Store-to-Storage initial sync verification
        XCTAssertNotNil(textContentStorage.attributedString)
        XCTAssertTrue(textContentStorage.attributedString?.string.contains("Initial Text") == true)
        
        // 2. Storage-to-Store sync verification
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .blockId: blockId,
            .blockType: BlockType.text
        ]
        let newAttributedString = NSAttributedString(string: "Updated Text from Editor", attributes: baseAttrs)
        
        // Update storage directly (simulating editor modifications)
        textContentStorage.attributedString = newAttributedString
        
        // Trigger synchronization
        coordinator.syncStorageToStore()
        
        XCTAssertEqual(store.blocks.count, 1)
        XCTAssertEqual(store.blocks[0].content, "Updated Text from Editor")
    }
}
