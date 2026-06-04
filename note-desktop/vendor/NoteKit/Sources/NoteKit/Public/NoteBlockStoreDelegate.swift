import Foundation

public protocol NoteBlockStoreDelegate: AnyObject {
    /// Fired when the entire blocks list is replaced or initialized.
    func blockStore(_ store: BlockStore, didUpdateBlocks blocks: [Block])
    
    /// Fired when a specific block is modified in place (e.g. content or checked state changed).
    func blockStore(_ store: BlockStore, didUpdateBlock block: Block, atIndex index: Int)
    
    /// Fired when a new block is inserted.
    func blockStore(_ store: BlockStore, didInsertBlock block: Block, atIndex index: Int)
    
    /// Fired when a block is removed.
    func blockStore(_ store: BlockStore, didRemoveBlockWithId id: UUID, atIndex index: Int)
}
