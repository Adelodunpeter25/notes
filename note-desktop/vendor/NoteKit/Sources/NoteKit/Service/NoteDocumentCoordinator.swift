import AppKit

public final class NoteDocumentCoordinator: NSObject, NSTextContentStorageDelegate, NSTextViewDelegate {
    public let store: BlockStore
    public let textContentStorage: NSTextContentStorage
    
    private var isSyncing = false
    
    public init(store: BlockStore, textContentStorage: NSTextContentStorage) {
        self.store = store
        self.textContentStorage = textContentStorage
        super.init()
        
        self.textContentStorage.delegate = self
        
        // Initial load sync
        syncStoreToStorage()
    }
    
    /// Updates the text backing store from the block state.
    public func syncStoreToStorage() {
        guard !isSyncing else { return }
        isSyncing = true
        
        let attributed = BlockToTextConverter.convert(blocks: store.blocks)
        textContentStorage.attributedString = attributed
        
        isSyncing = false
    }
    
    /// Parses the active text layout string back into blocks.
    public func syncStorageToStore() {
        guard !isSyncing else { return }
        isSyncing = true
        
        if let attributed = textContentStorage.attributedString {
            let updatedBlocks = TextToBlockConverter.parseBlocks(from: attributed)
            store.setBlocks(updatedBlocks)
        }
        
        isSyncing = false
    }
    
    // MARK: - NSTextContentStorageDelegate
    
    public func textContentStorage(_ textContentStorage: NSTextContentStorage, didProcessEditingRange editedRange: NSRange, changeInLength delta: Int, invalidatedRange: NSRange) {
        // Enqueue synchronization to avoid mutating during layout transactions
        DispatchQueue.main.async { [weak self] in
            self?.syncStorageToStore()
        }
    }
}
