import AppKit
import NoteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var mainSplitVC: MainSplitViewController?

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

        // 2. Setup macOS Window (Modern cmux-like configuration)
        let windowRect = NSRect(x: 0, y: 0, width: 1000, height: 700)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Notes"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 600)

        let toolbar = NSToolbar(identifier: "NotesToolbar")
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

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
            self.mainSplitVC = mainVC
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
                    self?.mainSplitVC = mainVC
                    self?.window.contentViewController = mainVC
                    self?.restoreWindowFrame()
                }
            }
            window.contentViewController = authVC
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        restoreWindowFrame()

        // 4. Setup Menu with Shortcuts
        NSApp.mainMenu = AppMenu(
            target: self,
            newNoteAction: #selector(handleNewNoteShortcut),
            newFolderAction: #selector(handleNewFolderShortcut)
        )
    }
    
    private func restoreWindowFrame() {
        window.identifier = NSUserInterfaceItemIdentifier("NotesMainWindow_v3")
        window.setFrameAutosaveName("NotesMainWindow_v3")
        _ = window.setFrameUsingName("NotesMainWindow_v3")
    }
    
    @objc private func handleNewNoteShortcut() {
        mainSplitVC?.createNewNote()
    }
    
    @objc private func handleNewFolderShortcut() {
        mainSplitVC?.createNewFolder()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Start NSApplication runloop manually
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
