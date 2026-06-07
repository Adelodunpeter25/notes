import AppKit
import NoteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var mainSplitVC: MainSplitViewController?
    
    private let database = Database(dbName: "note_app_db.sqlite")
    private lazy var storageService = StorageService(database: database)
    private lazy var apiService = ApiService()
    private lazy var authService = AuthService(storage: storageService, api: apiService)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize core layers & databases
        let recorder = SyncOpRecorder(storage: storageService)
        let searchService = SearchService(database: database)
        let noteService = NoteService(storage: storageService, recorder: recorder, searchService: searchService)
        let folderService = FolderService(storage: storageService, noteService: noteService, recorder: recorder)
        let syncService = SyncService(storage: storageService, api: apiService)

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
            showMainContent(userId: activeUserId, syncService: syncService, noteService: noteService, folderService: folderService)
        } else {
            showAuthContent(syncService: syncService, noteService: noteService, folderService: folderService)
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
    
    private func showMainContent(userId: String, syncService: SyncService, noteService: NoteService, folderService: FolderService) {
        let mainVC = MainSplitViewController(
            storage: storageService,
            folderService: folderService,
            noteService: noteService,
            userId: userId
        )
        self.mainSplitVC = mainVC
        
        mainVC.onLogout = { [weak self] in
            self?.handleLogout(syncService: syncService, noteService: noteService, folderService: folderService)
        }
        
        window.contentViewController = mainVC
        
        // Initial sync on launch
        syncService.syncData(userId: userId) { _ in
            DispatchQueue.main.async {
                mainVC.refreshAllData()
            }
        }
    }
    
    private func showAuthContent(syncService: SyncService, noteService: NoteService, folderService: FolderService) {
        let authVC = AuthViewController(authService: authService)
        authVC.onAuthSuccess = { [weak self] userId in
            DispatchQueue.main.async {
                self?.showMainContent(userId: userId, syncService: syncService, noteService: noteService, folderService: folderService)
            }
        }
        window.contentViewController = authVC
    }
    
    private func handleLogout(syncService: SyncService, noteService: NoteService, folderService: FolderService) {
        authService.logout()
        self.mainSplitVC = nil
        showAuthContent(syncService: syncService, noteService: noteService, folderService: folderService)
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
