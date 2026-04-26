import AppKit

func buildAppMenu() {
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "Quit Notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appMenuItem.submenu = appMenu

    // File menu
    let fileMenuItem = NSMenuItem()
    mainMenu.addItem(fileMenuItem)
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(NSMenuItem(title: "New Note", action: nil, keyEquivalent: "n"))
    fileMenu.addItem(NSMenuItem(title: "New Folder", action: nil, keyEquivalent: "N")) // Cmd+Shift+N
    fileMenuItem.submenu = fileMenu

    NSApplication.shared.mainMenu = mainMenu
}
