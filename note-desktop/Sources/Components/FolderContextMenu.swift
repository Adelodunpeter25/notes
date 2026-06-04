import AppKit

public final class FolderContextMenu: NSMenu {
    
    public init(target: AnyObject, renameAction: Selector, deleteAction: Selector) {
        super.init(title: "Folder Context")
        
        let renameItem = NSMenuItem(title: "Rename", action: renameAction, keyEquivalent: "")
        renameItem.target = target
        renameItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename")
        addItem(renameItem)
        
        let deleteItem = NSMenuItem(title: "Delete", action: deleteAction, keyEquivalent: "")
        deleteItem.target = target
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
        addItem(deleteItem)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
