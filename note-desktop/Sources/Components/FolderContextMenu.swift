import AppKit

public final class FolderContextMenu: NSMenu {
    public init() {
        super.init(title: "Folder Context")
        // Initialize with default items so AppKit always opens the menu
        addItem(withTitle: "Rename", action: nil, keyEquivalent: "")
        addItem(withTitle: "Delete", action: nil, keyEquivalent: "")
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(target: AnyObject, renameAction: Selector, deleteAction: Selector) {
        removeAllItems()
        
        let renameItem = NSMenuItem(title: "Rename", action: renameAction, keyEquivalent: "")
        renameItem.target = target
        addItem(renameItem)

        let deleteItem = NSMenuItem(title: "Delete", action: deleteAction, keyEquivalent: "")
        deleteItem.target = target
        addItem(deleteItem)
    }
}
