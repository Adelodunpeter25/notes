import AppKit

public final class NoteDocumentCoordinator: NSObject, NSTextContentStorageDelegate, NSTextViewDelegate {
    public let store: BlockStore
    public let textContentStorage: NSTextContentStorage
    
    private var isSyncing = false
    private var syncWorkItem: DispatchWorkItem?
    private let syncQueue = DispatchQueue(label: "com.notekit.syncQueue", qos: .userInitiated)
    
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
    
    /// Synchronously parses the active text layout string back into blocks (useful for tests or force-saves).
    public func syncStorageToStore() {
        guard !isSyncing else { return }
        isSyncing = true
        
        if let attributed = textContentStorage.attributedString {
            let updatedBlocks = TextToBlockConverter.parseBlocks(from: attributed)
            store.setBlocks(updatedBlocks)
        }
        
        isSyncing = false
    }
    
    /// Asynchronously parses the text snapshot on a background queue.
    private func syncStorageToStoreAsync() {
        guard !isSyncing else { return }
        
        // Capture a thread-safe snapshot of the attributed string on the main thread
        guard let attributedCopy = textContentStorage.attributedString?.copy() as? NSAttributedString else { return }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Perform CPU-heavy markdown formatting/serialization on background queue
            let updatedBlocks = TextToBlockConverter.parseBlocks(from: attributedCopy)
            
            DispatchQueue.main.async {
                guard !self.isSyncing else { return }
                self.isSyncing = true
                self.store.setBlocks(updatedBlocks)
                self.isSyncing = false
            }
        }
    }
    
    // MARK: - NSTextContentStorageDelegate
    
    public func textContentStorage(_ textContentStorage: NSTextContentStorage, didProcessEditingRange editedRange: NSRange, changeInLength delta: Int, invalidatedRange: NSRange) {
        // Cancel any pending sync requests to prevent multiple redundant runs
        syncWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.syncStorageToStoreAsync()
        }
        self.syncWorkItem = workItem
        
        // Debounce sync operations for 300ms of typing inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}
