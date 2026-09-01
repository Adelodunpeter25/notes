import AppKit
import NoteCore
import Observation

@available(macOS 14.0, *)
@Observable final class SyncState {
    var isSyncing = false
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var mainSplitVC: MainSplitViewController?
    private var activeUserId: String?
    
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

        // 2. Setup macOS Window (Modern Notes-like configuration)
        let windowRect = NSRect(x: 0, y: 0, width: 1000, height: 700)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 600)

        let toolbar = NSToolbar(identifier: "NotesToolbar_v4")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
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
        self.activeUserId = userId
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
        
        // Initial sync on launch (with toolbar sync button animation)
        animateSyncButton()
        syncService.syncData(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.stopSyncButtonAnimation()
                if case .success = result {
                    mainVC.refreshAllData()
                }
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
        self.activeUserId = nil
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
    
    @objc func handleFindShortcut() {
        mainSplitVC?.toggleFindInCurrentNote()
    }
    
    #if DEBUG
    @objc private func handleLogoutToolbarAction() {
        handleLogout()
    }
    #endif
    
    private var isSyncing = false

    private func animateSyncButton() {
        guard !isSyncing,
              let toolbar = window.toolbar,
              let syncItem = toolbar.items.first(where: { $0.itemIdentifier == NSToolbarItem.Identifier("sync") }),
              let button = syncItem.view as? NSButton else { return }
        isSyncing = true
        button.isEnabled = false
        button.alphaValue = 0.5
    }
    
    private func stopSyncButtonAnimation() {
        guard let toolbar = window.toolbar,
              let syncItem = toolbar.items.first(where: { $0.itemIdentifier == NSToolbarItem.Identifier("sync") }),
              let button = syncItem.view as? NSButton else {
            isSyncing = false
            return
        }
        button.isEnabled = true
        button.alphaValue = 1.0
        isSyncing = false
    }
    
    @objc private func handleSyncToolbarAction() {
        guard !isSyncing, let userId = activeUserId else { return }
        
        animateSyncButton()
        syncService.syncData(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.stopSyncButtonAnimation()
                if case .success = result {
                    self?.mainSplitVC?.refreshAllData()
                } else if case .failure(let error) = result {
                    let alert = NSAlert()
                    alert.messageText = "Sync Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let userId = activeUserId {
            noteService.autoDeleteEmptyNotes(userId: userId)
        }
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        if let userId = activeUserId {
            noteService.autoDeleteEmptyNotes(userId: userId)
            mainSplitVC?.refreshAllData()
        }
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
        } else if itemIdentifier == NSToolbarItem.Identifier("newNote") {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Note")
            button.target = self
            button.action = #selector(handleNewNoteShortcut)
            button.wantsLayer = true
            
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button
            item.label = "New Note"
            item.paletteLabel = "New Note"
            item.toolTip = "Create a New Note (⌘N)"
            return item
        } else if itemIdentifier == NSToolbarItem.Identifier("sync") {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Sync")
            button.target = self
            button.action = #selector(handleSyncToolbarAction)
            button.wantsLayer = true
            
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button
            item.label = "Sync"
            item.paletteLabel = "Sync"
            item.toolTip = "Sync Notes"
            return item
        }
        return nil
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar, .flexibleSpace, NSToolbarItem.Identifier("newNote"), .flexibleSpace, NSToolbarItem.Identifier("sync")]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar, .flexibleSpace, NSToolbarItem.Identifier("newNote"), .flexibleSpace, NSToolbarItem.Identifier("sync")]
    }
}

// Start NSApplication runloop manually
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
