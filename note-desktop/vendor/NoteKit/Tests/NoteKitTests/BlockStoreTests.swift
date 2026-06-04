import XCTest
@testable import NoteKit

final class MockBlockStoreDelegate: NoteBlockStoreDelegate {
    var updateBlocksCalled = false
    var updateBlockCalled = false
    var insertBlockCalled = false
    var removeBlockCalled = false
    
    var lastUpdatedBlocks: [Block]?
    var lastUpdatedBlock: Block?
    var lastInsertedBlock: Block?
    var lastRemovedId: UUID?
    
    func blockStore(_ store: BlockStore, didUpdateBlocks blocks: [Block]) {
        updateBlocksCalled = true
        lastUpdatedBlocks = blocks
    }
    
    func blockStore(_ store: BlockStore, didUpdateBlock block: Block, atIndex index: Int) {
        updateBlockCalled = true
        lastUpdatedBlock = block
    }
    
    func blockStore(_ store: BlockStore, didInsertBlock block: Block, atIndex index: Int) {
        insertBlockCalled = true
        lastInsertedBlock = block
    }
    
    func blockStore(_ store: BlockStore, didRemoveBlockWithId id: UUID, atIndex index: Int) {
        removeBlockCalled = true
        lastRemovedId = id
    }
}

final class BlockStoreTests: XCTestCase {
    
    func testBlockStoreCrudOperations() {
        let store = BlockStore()
        let delegate = MockBlockStoreDelegate()
        store.delegate = delegate
        
        let block1 = Block(type: .title, content: "Title")
        let block2 = Block(type: .text, content: "Hello world")
        
        // Test setBlocks
        store.setBlocks([block1, block2])
        XCTAssertTrue(delegate.updateBlocksCalled)
        XCTAssertEqual(store.blocks.count, 2)
        XCTAssertEqual(store.blocks[0].id, block1.id)
        
        // Test updateBlock
        store.updateBlock(id: block2.id, content: "Hello world updated")
        XCTAssertTrue(delegate.updateBlockCalled)
        XCTAssertEqual(store.blocks[1].content, "Hello world updated")
        
        // Test insertBlock
        let block3 = Block(type: .todo, content: "Buy groceries", isChecked: false)
        store.insertBlock(block3, at: 1)
        XCTAssertTrue(delegate.insertBlockCalled)
        XCTAssertEqual(store.blocks.count, 3)
        XCTAssertEqual(store.blocks[1].id, block3.id)
        
        // Test removeBlock
        store.removeBlock(id: block1.id)
        XCTAssertTrue(delegate.removeBlockCalled)
        XCTAssertEqual(delegate.lastRemovedId, block1.id)
        XCTAssertEqual(store.blocks.count, 2)
    }
}
