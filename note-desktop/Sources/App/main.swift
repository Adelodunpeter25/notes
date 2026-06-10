import AppKit
import NoteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var mainSplitVC: MainSplitViewController?
    
    private let database = Database(dbName: "note_app_db.sqlite")
    private lazy var storageService = StorageService(database: database)
    private lazy var apiService = ApiService()
    private lazy var authService = AuthService(storage: storageService, api: apiService)

    private var recorder: SyncOpRecorder!
    private var searchService: SearchService!
    private var noteService: NoteService!
    private var folderService: FolderService!
    private var syncService: SyncService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize core layers & databases
        self.recorder = SyncOpRecorder(storage: storageService)
        self.searchService = SearchService(database: database)
        self.noteService = NoteService(storage: storageService, recorder: recorder, searchService: searchService)
        self.folderService = FolderService(storage: storageService, noteService: noteService, recorder: recorder)
        self.syncService = SyncService(storage: storageService, api: apiService)

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
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 600)

        let toolbar = NSToolbar(identifier: "NotesToolbar")
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window.toolbar = toolbar

        // 3. Conditional routing based on active session
        if authService.getSessionToken() != nil,
           let firstUserRow = database.query(sql: "SELECT id FROM users LIMIT 1;").first,
           let activeUserId = firstUserRow["id"] as? String {
            showMainContent(userId: activeUserId)
        } else {
            showAuthContent()
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
    
    private func showMainContent(userId: String) {
        let mainVC = MainSplitViewController(
            storage: storageService,
            folderService: folderService,
            noteService: noteService,
            userId: userId
        )
        self.mainSplitVC = mainVC
        
        mainVC.onLogout = { [weak self] in
            self?.handleLogout()
        }
        
        window.contentViewController = mainVC
        
        // Initial sync on launch
        syncService.syncData(userId: userId) { _ in
            DispatchQueue.main.async {
                mainVC.refreshAllData()
            }
        }
    }
    
    private func showAuthContent() {
        let authVC = AuthViewController(authService: authService)
        authVC.onAuthSuccess = { [weak self] userId in
            DispatchQueue.main.async {
                self?.showMainContent(userId: userId)
            }
        }
        window.contentViewController = authVC
    }
    
    private func handleLogout() {
        authService.logout()
        self.mainSplitVC = nil
        showAuthContent()
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
    
    @objc private func handleLogoutToolbarAction() {
        handleLogout()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .toggleSidebar {
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        } else if itemIdentifier == NSToolbarItem.Identifier("logout") {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Log Out"
            item.paletteLabel = "Log Out"
            item.toolTip = "Log out of Notes"
            item.image = NSImage(systemSymbolName: "rectangle.portrait.and.arrow.right", accessibilityDescription: "Log Out")
            item.target = self
            item.action = #selector(handleLogoutToolbarAction)
            return item
        }
        return nil
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar, .flexibleSpace, NSToolbarItem.Identifier("logout")]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar, .flexibleSpace, NSToolbarItem.Identifier("logout")]
    }
}

// Start NSApplication runloop manually
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
