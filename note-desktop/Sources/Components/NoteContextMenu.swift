import AppKit

public final class NoteContextMenu: NSMenu {
    
    public init(
        note: DBNote?,
        target: AnyObject,
        pinAction: Selector,
        deleteAction: Selector,
        restoreAction: Selector
    ) {
        super.init(title: "Note Context")
        if let note = note {
            buildMenu(note: note, target: target, pinAction: pinAction, deleteAction: deleteAction, restoreAction: restoreAction)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(
        note: DBNote,
        target: AnyObject,
        pinAction: Selector,
        deleteAction: Selector,
        restoreAction: Selector
    ) {
        removeAllItems()
        buildMenu(note: note, target: target, pinAction: pinAction, deleteAction: deleteAction, restoreAction: restoreAction)
    }
    
    private func buildMenu(
        note: DBNote,
        target: AnyObject,
        pinAction: Selector,
        deleteAction: Selector,
        restoreAction: Selector
    ) {
        // 1. Pin/Unpin action
        let pinTitle = note.isPinned ? "Unpin Note" : "Pin Note"
        let pinItem = NSMenuItem(title: pinTitle, action: pinAction, keyEquivalent: "")
        pinItem.target = target
        pinItem.image = NSImage(systemSymbolName: note.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        addItem(pinItem)
        
        addItem(NSMenuItem.separator())
        
        // 2. Trash operations
        if note.deletedAt != nil {
            let restoreItem = NSMenuItem(title: "Restore Note", action: restoreAction, keyEquivalent: "")
            restoreItem.target = target
            restoreItem.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: nil)
            addItem(restoreItem)
            
            let deleteItem = NSMenuItem(title: "Delete Permanently", action: deleteAction, keyEquivalent: "")
            deleteItem.target = target
            deleteItem.image = NSImage(systemSymbolName: "trash.slash", accessibilityDescription: nil)
            addItem(deleteItem)
        } else {
            let trashItem = NSMenuItem(title: "Move to Trash", action: deleteAction, keyEquivalent: "")
            trashItem.target = target
            trashItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            addItem(trashItem)
        }
    }
}
