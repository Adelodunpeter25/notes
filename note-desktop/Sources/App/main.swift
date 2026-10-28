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
        // The tracking separators bind to this split view's dividers, so the toolbar is
        // built after it exists and replaced whenever the main content is recreated.
        window.toolbar = makeToolbar()
        
        // Initial sync on launch (with toolbar sync button animation)
        animateSyncButton()
        syncService.syncData(userId: userId) { [weak self] result in
            Task { @MainActor in
                self?.stopSyncButtonAnimation()
                if case .success = result {
                    self?.mainSplitVC?.refreshAllData()
                } else if case .failure(let error) = result {
                    // Background sync on launch stays quiet, except for a dead session.
                    self?.handleSyncFailure(error, alertForOtherErrors: false)
                }
            }
        }
    }
    
    /// A 401 means the token is no longer valid: sign out and return to the login screen
    /// (local notes and queued changes are kept and sync after the next login).
    private func handleSyncFailure(_ error: Error, alertForOtherErrors: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if case SyncError.sessionExpired = error {
            handleLogout()
            alert.messageText = "Session Expired"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return
        }
        guard alertForOtherErrors else { return }
        alert.messageText = "Sync Failed"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
    
    private func showAuthContent() {
        let authVC = AuthViewController(authService: authService)
        authVC.onAuthSuccess = { [weak self] userId in
            Task { @MainActor in self?.showMainContent(userId: userId) }
        }
        window.contentViewController = authVC
        // New Note / Sync do nothing on the login screen, so don't show them.
        window.toolbar = nil
    }
    
    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "NotesToolbar_v5")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        return toolbar
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

    private func setSyncItemEnabled(_ enabled: Bool) {
        window.toolbar?.items
            .first(where: { $0.itemIdentifier == AppDelegate.syncItemID })?
            .isEnabled = enabled
    }
    
    private func animateSyncButton() {
        guard !isSyncing else { return }
        isSyncing = true
        setSyncItemEnabled(false)
    }
    
    private func stopSyncButtonAnimation() {
        setSyncItemEnabled(true)
        isSyncing = false
    }
    
    @objc private func handleSyncToolbarAction() {
        guard !isSyncing, let userId = activeUserId else { return }
        
        animateSyncButton()
        syncService.syncData(userId: userId) { [weak self] result in
            Task { @MainActor in
                self?.stopSyncButtonAnimation()
                if case .success = result {
                    self?.mainSplitVC?.refreshAllData()
                } else if case .failure(let error) = result {
                    self?.handleSyncFailure(error, alertForOtherErrors: true)
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
    static let newNoteItemID = NSToolbarItem.Identifier("newNote")
    static let syncItemID = NSToolbarItem.Identifier("sync")
    static let editorTrackingSeparatorID = NSToolbarItem.Identifier("editorTrackingSeparator")
    
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case AppDelegate.newNoteItemID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Note")
            item.label = "New Note"
            item.paletteLabel = "New Note"
            item.toolTip = "Create a New Note (⌘N)"
            item.target = self
            item.action = #selector(handleNewNoteShortcut)
            return item
            
        case AppDelegate.syncItemID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Sync")
            item.label = "Sync"
            item.paletteLabel = "Sync"
            item.toolTip = "Sync Notes"
            item.target = self
            item.action = #selector(handleSyncToolbarAction)
            // Enabled state is driven by the sync lifecycle, not by menu validation.
            item.autovalidates = false
            return item
            
        case AppDelegate.editorTrackingSeparatorID:
            // Divider 1 sits between the note list and the editor.
            if let splitView = mainSplitVC?.splitView {
                return NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: splitView, dividerIndex: 1)
            }
            return nil
            
        default:
            return nil
        }
    }
    
    /// Sidebar toggle | sidebar divider | … New Note (right edge of the note list) | divider | … Sync
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            AppDelegate.newNoteItemID,
            AppDelegate.editorTrackingSeparatorID,
            .flexibleSpace,
            AppDelegate.syncItemID
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}

// Start NSApplication runloop manually
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

extension AppDelegate: @unchecked Sendable {}
