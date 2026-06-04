import Foundation

public final class BlockStore {
    public private(set) var blocks: [Block] = []
    public weak var delegate: NoteBlockStoreDelegate?
    
    public init(blocks: [Block] = []) {
        self.blocks = blocks
    }
    
    /// Initializes or replaces the entire blocks list.
    public func setBlocks(_ newBlocks: [Block]) {
        self.blocks = newBlocks
        delegate?.blockStore(self, didUpdateBlocks: newBlocks)
    }
    
    /// Updates an existing block's content and/or checked state.
    public func updateBlock(id: UUID, content: String, isChecked: Bool? = nil) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].content = content
        if let isChecked = isChecked {
            blocks[index].isChecked = isChecked
        }
        delegate?.blockStore(self, didUpdateBlock: blocks[index], atIndex: index)
    }
    
    /// Inserts a new block at the specified index.
    public func insertBlock(_ block: Block, at index: Int) {
        let safeIndex = max(0, min(index, blocks.count))
        blocks.insert(block, at: safeIndex)
        delegate?.blockStore(self, didInsertBlock: block, atIndex: safeIndex)
    }
    
    /// Removes a block from the store by its unique ID.
    public func removeBlock(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks.remove(at: index)
        delegate?.blockStore(self, didRemoveBlockWithId: id, atIndex: index)
    }
}
