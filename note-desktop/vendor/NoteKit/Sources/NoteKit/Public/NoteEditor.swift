import AppKit

public final class NoteEditor: NSViewController, NoteBlockStoreDelegate {
    private var store: BlockStore?
    private var coordinator: NoteDocumentCoordinator?
    public private(set) var textView: NSTextView!
    public private(set) var scrollView: NSScrollView!
    
    // Strong references to manual TextKit 2 pipeline components
    private let textContentStorage = NSTextContentStorage()
    private let textLayoutManager = NSTextLayoutManager()
    private let textContainer = NSTextContainer()
    
    public var onBlocksUpdated: (([Block]) -> Void)?
    
    public override func loadView() {
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        // 1. Wire up the TextKit 2 pipeline
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.textContainer = textContainer
        
        textContainer.widthTracksTextView = true
        let contentSize = scrollView.contentSize
        textContainer.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        // 2. Instantiate and configure NSTextView
        textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.wantsLayer = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        
        scrollView.documentView = textView
        self.view = scrollView
    }
    
    public func loadBlocks(_ blocks: [Block]) {
        let store = BlockStore(blocks: blocks)
        store.delegate = self
        self.store = store
        
        BlockToTextConverter.clearCache()
        
        let coordinator = NoteDocumentCoordinator(store: store, textContentStorage: textContentStorage)
        textView.delegate = coordinator
        self.coordinator = coordinator
        
        // Force initial load of blocks to text storage
        coordinator.syncStoreToStorage()
        
        textView.allowsUndo = true
    }
    
    public func getBlocks() -> [Block] {
        return store?.blocks ?? []
    }
    
    public func toggleChecklist() {
        guard let store = store else { return }
              
        let selectedRange = textView.selectedRange()
        guard selectedRange.location != NSNotFound else { return }
        
        guard let storageString = textContentStorage.attributedString, storageString.length > 0 else { return }
        
        let location = min(selectedRange.location, storageString.length - 1)
        guard let blockId = storageString.attribute(.blockId, at: location, effectiveRange: nil) as? UUID else { return }
        guard let index = store.blocks.firstIndex(where: { $0.id == blockId }) else { return }
        
        var updatedBlocks = store.blocks
        let currentBlock = updatedBlocks[index]
        
        if currentBlock.type == BlockType.todo {
            updatedBlocks[index].type = BlockType.text
            updatedBlocks[index].isChecked = nil
        } else {
            updatedBlocks[index].type = BlockType.todo
            updatedBlocks[index].isChecked = false
        }
        
        store.setBlocks(updatedBlocks)
        coordinator?.syncStoreToStorage()
        
        // Restore selection safely
        let newLength = textContentStorage.attributedString?.length ?? 0
        let safeLocation = min(selectedRange.location, newLength)
        let safeLength = min(selectedRange.length, newLength - safeLocation)
        textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
    }
    
    // MARK: - NoteBlockStoreDelegate
    
    public func blockStore(_ store: BlockStore, didUpdateBlocks blocks: [Block]) {
        onBlocksUpdated?(blocks)
    }
    
    public func blockStore(_ store: BlockStore, didUpdateBlock block: Block, atIndex index: Int) {
        onBlocksUpdated?(store.blocks)
    }
    
    public func blockStore(_ store: BlockStore, didInsertBlock block: Block, atIndex index: Int) {
        onBlocksUpdated?(store.blocks)
    }
    
    public func blockStore(_ store: BlockStore, didRemoveBlockWithId id: UUID, atIndex index: Int) {
        onBlocksUpdated?(store.blocks)
    }
}
