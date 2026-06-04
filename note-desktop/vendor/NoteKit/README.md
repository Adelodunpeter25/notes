# NoteKit

NoteKit is a lightweight, high-performance TextKit 2 engine designed for native macOS rich-text editors. It maps a structured, block-based JSON data model to standard `NSAttributedString` layout buffers, enabling smooth bidirectional editing, custom paragraph layouts, and interactive todo checkmarks.

## Key Features

* **TextKit 2 Integration**: Custom drawing overlays and view attachments for checklist/todo controls.
* **Inline Markdown Formatting**: Translates simple markdown traits (`**bold**`, `*italic*`, `[label](url)`) to attributed styles on read, and serializes them back to markdown plain-text on write.
* **Stateless Cache Optimization**: Automatically caches rendered text strings to maintain O(1) performance during active typing.
* **Keystroke Debouncing**: Throttles updates back to the block state, optimizing database write/network synchronization workloads.

---

## Directory Structure

```
vendor/NoteKit/
├── Package.swift
├── Sources/NoteKit/
│   ├── Models/      # Core models: Block, BlockType, NSAttributedString extensions
│   ├── Public/      # BlockStore state engine and delegate protocols
│   ├── Service/     # Converters and Bidirectional NoteDocumentCoordinator
│   └── Utils/       # TodoAttachment view provider & custom NoteLayoutFragment
└── Tests/NoteKitTests/
```

---

## Integration Example

### 1. Initialize NoteKit
Call `NoteKit.initialize()` in your application entry point to register interactive text attachment view providers:

```swift
import SwiftUI
import NoteKit

@main
struct NoteApp: App {
    init() {
        NoteKit.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. SwiftUI TextView Bindings
Use `NSViewRepresentable` to bridge AppKit’s `NSTextView` to SwiftUI, synchronizing the editor view with the `BlockStore` through the `NoteDocumentCoordinator`:

```swift
import SwiftUI
import AppKit
import NoteKit

struct NoteCanvas: NSViewRepresentable {
    let store: BlockStore
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create TextKit 2 layout pipeline
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        
        let container = NSTextContainer(containerSize: .zero)
        layoutManager.addTextContainer(container)
        
        // Instantiate the document coordinator (starts initial load)
        let coordinator = NoteDocumentCoordinator(store: store, textContentStorage: contentStorage)
        context.coordinator.documentCoordinator = coordinator
        
        // Build viewport
        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.delegate = coordinator
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.documentCoordinator?.syncStoreToStorage()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var documentCoordinator: NoteDocumentCoordinator?
    }
}
```
