import AppKit
import NoteKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize core layers & databases
        let database = Database(dbName: "note_app_db.sqlite")
        let storageService = StorageService(database: database)
        let recorder = SyncOpRecorder(storage: storageService)
        let apiService = ApiService()
        let authService = AuthService(storage: storageService, api: apiService)
        let noteService = NoteService(storage: storageService, recorder: recorder)
        let folderService = FolderService(storage: storageService, noteService: noteService, recorder: recorder)
        
        // Setup local fallback session so the app functions instantly offline
        let activeUserId: String
        if authService.getSessionToken() != nil,
           let firstUserRow = database.query(sql: "SELECT id FROM users LIMIT 1;").first,
           let id = firstUserRow["id"] as? String {
            activeUserId = id
        } else {
            let fallbackId = "local_user_id"
            let localUser = DBUser(id: fallbackId, username: "Local User", email: "local@notes.com")
            _ = storageService.insertUser(localUser)
            activeUserId = fallbackId
        }
        
        // 2. Setup macOS Window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Notes"
        window.titlebarAppearsTransparent = true
        window.center()
        
        // 3. Setup Split Layout Content View
        let mainSplitViewController = MainSplitViewController(
            storage: storageService,
            folderService: folderService,
            noteService: noteService,
            userId: activeUserId
        )
        
        window.contentViewController = mainSplitViewController
        window.makeKeyAndOrderFront(nil)
        
        setupMenu()
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Notes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu (Essential for text editing shortcuts!)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSStandardKeyBindingResponding.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Start NSApplication runloop
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
