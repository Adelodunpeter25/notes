# NoteKit Implementation Guide

This guide outlines the architecture and interfaces for mapping a block-based JSON data model to Apple's **TextKit 2** rendering engine. It defines the core data structures, conversion pipelines, and delegate protocols needed to drive a native macOS rich-text editor canvas.

---

## 1. Architectural Overview

```
 ┌────────────────────────────────────────┐
 │           SwiftUI / AppKit UI          │  (Display Layer)
 └───────────────────▲────────────────────┘
                     │ NSViewRepresentable (Bidirectional Binding)
 ┌───────────────────▼────────────────────┐
 │               NSTextView               │  (Viewport & Input Editor)
 └───────────────────▲────────────────────┘
                     │ TextKit 2 Subsystems
 ┌───────────────────▼────────────────────┐
 │         NSTextLayoutManager            │  (Coordinates Rendering & Layout)
 └───────────────────▲────────────────────┘
                     │ Element Tree
 ┌───────────────────▼────────────────────┐
 │         NSTextContentStorage           │  (Translates Elements to Paragraphs)
 └───────────────────▲────────────────────┘
                     │ Reads / Writes
 ┌───────────────────▼────────────────────┐
 │      NoteDocumentCoordinator           │  (Converts NSAttributedString ⇄ Block JSON)
 └───────────────────▲────────────────────┘
                     │ Bidirectional Sync
 ┌───────────────────▼────────────────────┐
 │             BlockStore                 │  (Single Source of Truth / Client State)
 └────────────────────────────────────────┘
```

The core insight is separating the **Sync Model** (JSON block arrays) from the **Render Model** (`NSAttributedString`). 

* **Read Pipeline:** `[JSON Block]` ➔ `BlockToTextConverter` ➔ `NSAttributedString` (with custom attributes like `.blockId`) ➔ `NSTextContentStorage`.
* **Write Pipeline:** User types ➔ `NSTextContentStorageDelegate` identifies the modified character range ➔ `TextToBlockConverter` extracts the paragraph-level attributes ➔ Updates specific blocks in `BlockStore`.

---

## 2. Core Data Models

### Block Definition

```swift
import Foundation

public enum BlockType: String, Codable {
    case heading
    case text
    case checklist
    case code
}

public struct Block: Identifiable, Codable {
    public let id: UUID
    public var type: BlockType
    public var content: String
    public var isChecked: Bool? // Only used for checklist blocks
    
    public init(id: UUID = UUID(), type: BlockType, content: String, isChecked: Bool? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.isChecked = isChecked
    }
}
```

### Custom AttributedString Attributes

```swift
import Foundation

public extension NSAttributedString.Key {
    /// Tracks which Block ID a character range belongs to.
    static let blockId = NSAttributedString.Key("NoteKit.blockId")
    /// Tracks the block type (heading, checklist, etc.) for layout styling.
    static let blockType = NSAttributedString.Key("NoteKit.blockType")
    /// Track checkbox state (checked/unchecked) for rendering.
    static let blockCheckedState = NSAttributedString.Key("NoteKit.blockCheckedState")
}
```

---

## 3. Communication Protocols & Delegates

### `NoteBlockStoreDelegate`
Implement this protocol on the UI or sync coordinator side to listen to incremental block changes.

```swift
public protocol NoteBlockStoreDelegate: AnyObject {
    /// Fired when blocks are updated from typing/actions.
    func blockStore(_ store: BlockStore, didUpdateBlocks blocks: [Block])
    /// Fired when a specific block was modified.
    func blockStore(_ store: BlockStore, didUpdateBlock block: Block, atIndex index: Int)
}
```

### `NoteEditorDelegate`
Implement this protocol in your AppKit view controller or SwiftUI coordinator to catch specialized keystrokes (like Backspace on an empty list item or Enter inside a block).

```swift
import AppKit

public protocol NoteEditorDelegate: AnyObject {
    /// Requests editor to split a block at the cursor's current paragraph position.
    func editor(_ editor: NSTextView, didRequestSplitBlockAt characterIndex: Int)
    
    /// Requests editor to change a block type (e.g. converting a Checklist item back to plain Text on backspace).
    func editor(_ editor: NSTextView, didRequestChangeBlockTypeAt characterIndex: Int, to type: BlockType)
}
```

---

## 4. Proposed File Structures & Responsibilities

For the `vendor/NoteKit/Sources/NoteKit` directory structure, organize classes into separate files under their corresponding subfolders:

### A. Public / API Interfaces (`Public/`)

#### `BlockStore.swift`
Manages the source-of-truth collection of blocks for the active note.
```swift
import Foundation

public final class BlockStore {
    public private(set) var blocks: [Block] = []
    public weak var delegate: NoteBlockStoreDelegate?
    
    public init(blocks: [Block] = []) {
        self.blocks = blocks
    }
    
    public func setBlocks(_ newBlocks: [Block]) {
        self.blocks = newBlocks
        delegate?.blockStore(self, didUpdateBlocks: newBlocks)
    }
    
    public func updateBlock(id: UUID, content: String, isChecked: Bool? = nil) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].content = content
        if let isChecked = isChecked {
            blocks[index].isChecked = isChecked
        }
        delegate?.blockStore(self, didUpdateBlock: blocks[index], atIndex: index)
    }
}
```

### B. Service / Translation Layer (`Service/`)

#### `BlockToTextConverter.swift`
Translates block structures to `NSAttributedString` ranges with unique metadata keys.
```swift
import AppKit

public final class BlockToTextConverter {
    public static func convert(blocks: [Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for (index, block) in blocks.enumerated() {
            let paragraphContent = block.content + (index < blocks.count - 1 ? "\n" : "")
            let attributes = buildAttributes(for: block)
            let attributedParagraph = NSAttributedString(string: paragraphContent, attributes: attributes)
            result.append(attributedParagraph)
        }
        
        return result
    }
    
    private static func buildAttributes(for block: Block) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .blockId: block.id,
            .blockType: block.type
        ]
        
        // Define fonts and paragraph spacing based on block type
        switch block.type {
        case .heading:
            attrs[.font] = NSFont.boldSystemFont(ofSize: 22)
        case .text:
            attrs[.font] = NSFont.systemFont(ofSize: 14)
        case .checklist:
            attrs[.font] = NSFont.systemFont(ofSize: 14)
            attrs[.blockCheckedState] = block.isChecked ?? false
        case .code:
            attrs[.font] = NSFont.userFixedPitchFont(ofSize: 13) ?? NSFont.systemFont(ofSize: 13)
        }
        
        return attrs
    }
}
```

#### `TextToBlockConverter.swift`
Parses attributes out of updated text ranges to build incremental Block models.
```swift
import AppKit

public final class TextToBlockConverter {
    public static func parseBlocks(from attributedString: NSAttributedString) -> [Block] {
        var blocks: [Block] = []
        
        attributedString.enumerateAttribute(.blockId, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            guard let blockId = value as? UUID else { return }
            
            let rawString = attributedString.attributedSubstring(from: range).string
            let cleanedString = rawString.trimmingCharacters(in: .newlines)
            let type = attributedString.attribute(.blockType, at: range.location, effectiveRange: nil) as? BlockType ?? .text
            let isChecked = attributedString.attribute(.blockCheckedState, at: range.location, effectiveRange: nil) as? Bool
            
            let block = Block(id: blockId, type: type, content: cleanedString, isChecked: isChecked)
            blocks.append(block)
        }
        
        return blocks
    }
}
```

### C. Utils / Layout Layer (`Utils/`)

#### `NoteLayoutFragment.swift`
Custom TextKit 2 `NSTextLayoutFragment` wrapper to customize rendering boundaries (e.g. checkbox padding, code block background drawing).
```swift
import AppKit

public final class NoteLayoutFragment: NSTextLayoutFragment {
    // Custom drawing overrides for block level decorations (like code block background colors)
    public override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        
        // Custom background decorations can be rendered here directly to the graphics context
    }
}
```
