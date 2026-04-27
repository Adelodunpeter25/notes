import AppKit

// MARK: - Notification names for menu actions

extension Notification.Name {
    static let newNoteRequested   = Notification.Name("com.notes.newNote")
    static let newFolderRequested = Notification.Name("com.notes.newFolder")
}

// MARK: - Menu builder

func buildAppMenu() {
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(
        title: "Quit Notes",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    appMenuItem.submenu = appMenu

    // File menu
    let fileMenuItem = NSMenuItem()
    mainMenu.addItem(fileMenuItem)
    let fileMenu = NSMenu(title: "File")

    let newNoteItem = NSMenuItem(
        title: "New Note",
        action: #selector(AppMenuResponder.newNote(_:)),
        keyEquivalent: "n"
    )
    fileMenu.addItem(newNoteItem)

    let newFolderItem = NSMenuItem(
        title: "New Folder",
        action: #selector(AppMenuResponder.newFolder(_:)),
        keyEquivalent: "N"   // Cmd+Shift+N
    )
    fileMenu.addItem(newFolderItem)

    fileMenuItem.submenu = fileMenu

    NSApplication.shared.mainMenu = mainMenu

    // The responder is now installed inside NotesApp.swift
    // after the window is created.
}

// MARK: - Responder

/// Sits in the AppKit responder chain and converts menu-item actions into
/// `NotificationCenter` broadcasts that SwiftUI views observe with `.onReceive`.
final class AppMenuResponder: NSResponder {
    static let shared = AppMenuResponder()

    /// Call once after the window is created so this responder is reached
    /// before the default "no handler" beep.
    static func install(in window: NSWindow) {
        let previous = window.nextResponder
        window.nextResponder = shared
        shared.nextResponder  = previous
    }

    @objc func newNote(_ sender: Any?) {
        NotificationCenter.default.post(name: .newNoteRequested, object: nil)
    }

    @objc func newFolder(_ sender: Any?) {
        NotificationCenter.default.post(name: .newFolderRequested, object: nil)
    }
}
