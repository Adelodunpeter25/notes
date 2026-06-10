import AppKit

public final class NoteContextMenu: NSMenu {
    
    public init(
        target: AnyObject,
        pinAction: Selector,
        deleteAction: Selector,
        restoreAction: Selector,
        moveAction: Selector
    ) {
        super.init(title: "Note Context")
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(
        note: DBNote,
        folders: [DBFolder],
        target: AnyObject,
        pinAction: Selector,
        deleteAction: Selector,
        restoreAction: Selector,
        moveAction: Selector
    ) {
        removeAllItems()
        
        // 1. Pin/Unpin action
        let pinTitle = note.isPinned ? "Unpin Note" : "Pin Note"
        let pinItem = NSMenuItem(title: pinTitle, action: pinAction, keyEquivalent: "")
        pinItem.target = target
        addItem(pinItem)
        
        addItem(NSMenuItem.separator())
        
        // 2. Move to Folder (Only for active notes)
        if note.deletedAt == nil {
            let moveItem = NSMenuItem(title: "Move to Folder", action: nil, keyEquivalent: "")
            let subMenu = NSMenu()
            
            // All Notes (Remove from folder)
            let allNotesItem = NSMenuItem(title: "All Notes", action: moveAction, keyEquivalent: "")
            allNotesItem.target = target
            allNotesItem.representedObject = nil // Signals moving out of any folder
            if note.folderId == nil { allNotesItem.state = .on }
            subMenu.addItem(allNotesItem)
            
            if !folders.isEmpty {
                subMenu.addItem(NSMenuItem.separator())
                for folder in folders {
                    let folderItem = NSMenuItem(title: folder.name, action: moveAction, keyEquivalent: "")
                    folderItem.target = target
                    folderItem.representedObject = folder.id
                    if note.folderId == folder.id { folderItem.state = .on }
                    subMenu.addItem(folderItem)
                }
            }
            
            moveItem.submenu = subMenu
            addItem(moveItem)
            addItem(NSMenuItem.separator())
        }
        
        // 3. Trash operations
        if note.deletedAt != nil {
            let restoreItem = NSMenuItem(title: "Restore Note", action: restoreAction, keyEquivalent: "")
            restoreItem.target = target
            addItem(restoreItem)
            
            let deleteItem = NSMenuItem(title: "Delete Permanently", action: deleteAction, keyEquivalent: "")
            deleteItem.target = target
            addItem(deleteItem)
        } else {
            let trashItem = NSMenuItem(title: "Move to Trash", action: deleteAction, keyEquivalent: "")
            trashItem.target = target
            addItem(trashItem)
        }
    }
}
