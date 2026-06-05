import AppKit
import NoteKit
import NoteCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize core layers & databases
        let database = Database(dbName: "note_app_db.sqlite")
        let storageService = StorageService(database: database)
        let recorder = SyncOpRecorder(storage: storageService)
        let apiService = ApiService()
        let authService = AuthService(storage: storageService, api: apiService)
        let searchService = SearchService(database: database)
        let noteService = NoteService(storage: storageService, recorder: recorder, searchService: searchService)
        let folderService = FolderService(storage: storageService, noteService: noteService, recorder: recorder)

        // 2. Setup macOS Window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Notes"
        window.titlebarAppearsTransparent = true
        
        // Native Window Persistence (Matches cmux implementation)
        window.setFrameAutosaveName("NotesMainWindow")

        // 3. Conditional routing based on active session
        if authService.getSessionToken() != nil,
           let firstUserRow = database.query(sql: "SELECT id FROM users LIMIT 1;").first,
           let activeUserId = firstUserRow["id"] as? String {
            let mainVC = MainSplitViewController(
                storage: storageService,
                folderService: folderService,
                noteService: noteService,
                userId: activeUserId
            )
            window.contentViewController = mainVC
        } else {
            let authVC = AuthViewController(authService: authService)
            authVC.onAuthSuccess = { [weak self] userId in
                DispatchQueue.main.async {
                    let mainVC = MainSplitViewController(
                        storage: storageService,
                        folderService: folderService,
                        noteService: noteService,
                        userId: userId
                    )
                    self?.window.contentViewController = mainVC
                }
            }
            window.contentViewController = authVC
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
