import AppKit

public final class AppMenu: NSMenu {
    
    public init(
        target: AnyObject,
        newNoteAction: Selector,
        newFolderAction: Selector
    ) {
        super.init(title: "")
        setupMenu(target: target, newNoteAction: newNoteAction, newFolderAction: newFolderAction)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMenu(
        target: AnyObject,
        newNoteAction: Selector,
        newFolderAction: Selector
    ) {
        // 1. Application Menu
        let appMenuItem = NSMenuItem()
        addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Notes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        
        let newNoteItem = NSMenuItem(title: "New Note", action: newNoteAction, keyEquivalent: "n")
        newNoteItem.target = target
        fileMenu.addItem(newNoteItem)
        
        let newFolderItem = NSMenuItem(title: "New Folder", action: newFolderAction, keyEquivalent: "N")
        newFolderItem.keyEquivalentModifierMask = [.command, .shift]
        newFolderItem.target = target
        fileMenu.addItem(newFolderItem)
        
        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSStandardKeyBindingResponding.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        
        let findItem = NSMenuItem(title: "Find in Note…", action: #selector(AppDelegate.handleFindShortcut), keyEquivalent: "f")
        findItem.target = target
        editMenu.addItem(findItem)
    }
}
