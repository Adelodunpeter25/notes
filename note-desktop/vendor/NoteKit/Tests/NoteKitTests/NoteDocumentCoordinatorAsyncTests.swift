import XCTest
@testable import NoteKit

final class NoteDocumentCoordinatorAsyncTests: XCTestCase {
    
    func testCoordinatorDebouncedAsyncSync() throws {
        let blockId = UUID()
        let store = BlockStore(blocks: [
            Block(id: blockId, type: .text, content: "Initial Text")
        ])
        
        let textContentStorage = NSTextContentStorage()
        let coordinator = NoteDocumentCoordinator(store: store, textContentStorage: textContentStorage)
        
        // 1. Update text storage to trigger the delegate editing event
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .blockId: blockId,
            .blockType: BlockType.text
        ]
        let newAttributedString = NSAttributedString(string: "Async Typed Text", attributes: baseAttrs)
        
        // Simulate typing by triggering the delegate callback
        textContentStorage.attributedString = newAttributedString
        coordinator.textContentManager(textContentStorage, didProcessEditingRange: NSRange(location: 0, length: 16), changeInLength: 16, invalidatedRange: NSRange(location: 0, length: 16))
        
        // 2. Immediately after editing, the block content should still be "Initial Text" due to 300ms debounce
        XCTAssertEqual(store.blocks[0].content, "Initial Text")
        
        // 3. Set up expectation to wait for the debounce timer (300ms) to fire and update the store
        let expectation = self.expectation(description: "Wait for debounce and background sync")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertEqual(store.blocks[0].content, "Async Typed Text")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
