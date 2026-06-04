import XCTest
@testable import NoteCore

final class ServiceTests: XCTestCase {
    private var database: Database!
    private var storage: StorageService!
    private var recorder: SyncOpRecorder!
    private var searchService: SearchService!
    private var noteService: NoteService!
    private var folderService: FolderService!
    
    private let testUserId = "user_test_123"
    
    override func setUp() {
        super.setUp()
        // Initialize a clean, isolated in-memory database for each test run
        database = Database(dbName: ":memory:")
        storage = StorageService(database: database)
        recorder = SyncOpRecorder(storage: storage)
        searchService = SearchService(database: database)
        noteService = NoteService(storage: storage, recorder: recorder, searchService: searchService)
        folderService = FolderService(storage: storage, noteService: noteService, recorder: recorder)
        
        // Setup a dummy user in SQLite since user_id has foreign key constraints on sync records if any
        _ = database.execute(
            sql: "INSERT INTO users (id, username, email) VALUES (?, ?, ?);",
            params: [testUserId, "testuser", "test@example.com"]
        )
    }
    
    override func tearDown() {
        database = nil
        storage = nil
        recorder = nil
        searchService = nil
        noteService = nil
        folderService = nil
        super.tearDown()
    }
    
    func testCreateNote() {
        let title = "Test Note Title"
        let content = "Test Note Body Content"
        
        guard let note = noteService.createNote(title: title, content: content, userId: testUserId) else {
            XCTFail("Failed to create note")
            return
        }
        
        XCTAssertEqual(note.title, title)
        XCTAssertEqual(note.content, content)
        XCTAssertEqual(note.userId, testUserId)
        XCTAssertFalse(note.isPinned)
        XCTAssertNil(note.folderId)
        
        // Verify it persists in storage
        let activeNotes = storage.listActiveNotes(userId: testUserId)
        XCTAssertEqual(activeNotes.count, 1)
        XCTAssertEqual(activeNotes.first?.id, note.id)
        XCTAssertEqual(activeNotes.first?.title, title)
    }
    
    func testPinNote() {
        guard let note = noteService.createNote(title: "Pin Me", content: "Body", userId: testUserId) else {
            XCTFail("Failed to create note")
            return
        }
        
        XCTAssertFalse(note.isPinned)
        
        // Pin it
        let pinnedSuccess = noteService.pinNote(note, isPinned: true)
        XCTAssertTrue(pinnedSuccess)
        
        // Fetch from storage to confirm
        let activeNotes = storage.listActiveNotes(userId: testUserId)
        XCTAssertEqual(activeNotes.count, 1)
        XCTAssertTrue(activeNotes.first?.isPinned ?? false)
        
        // Unpin it
        let unpinnedSuccess = noteService.pinNote(activeNotes.first!, isPinned: false)
        XCTAssertTrue(unpinnedSuccess)
        
        let activeNotesAfterUnpin = storage.listActiveNotes(userId: testUserId)
        XCTAssertFalse(activeNotesAfterUnpin.first?.isPinned ?? true)
    }
    
    func testSoftDeleteAndRestoreNote() {
        guard let note = noteService.createNote(title: "Delete Me", content: "Content", userId: testUserId) else {
            XCTFail("Failed to create note")
            return
        }
        
        // Verify initially active
        XCTAssertEqual(storage.listActiveNotes(userId: testUserId).count, 1)
        XCTAssertEqual(storage.listTrashNotes(userId: testUserId).count, 0)
        
        // Soft delete
        let deleteSuccess = noteService.softDeleteNote(note)
        XCTAssertTrue(deleteSuccess)
        
        // Verify moved to trash
        XCTAssertEqual(storage.listActiveNotes(userId: testUserId).count, 0)
        let trashNotes = storage.listTrashNotes(userId: testUserId)
        XCTAssertEqual(trashNotes.count, 1)
        XCTAssertEqual(trashNotes.first?.id, note.id)
        
        // Restore note
        let restoreSuccess = noteService.restoreNote(trashNotes.first!)
        XCTAssertTrue(restoreSuccess)
        
        // Verify active again
        XCTAssertEqual(storage.listActiveNotes(userId: testUserId).count, 1)
        XCTAssertEqual(storage.listTrashNotes(userId: testUserId).count, 0)
    }
    
    func testCreateFolderAndMoveNote() {
        let folderName = "Work"
        guard let folder = folderService.createFolder(name: folderName, userId: testUserId) else {
            XCTFail("Failed to create folder")
            return
        }
        
        XCTAssertEqual(folder.name, folderName)
        XCTAssertEqual(folder.userId, testUserId)
        
        // Create a note
        guard let note = noteService.createNote(title: "Work Note", content: "Work content", userId: testUserId) else {
            XCTFail("Failed to create note")
            return
        }
        
        XCTAssertNil(note.folderId)
        
        // Move note to folder
        let moveSuccess = noteService.moveNoteToFolder(note, folderId: folder.id)
        XCTAssertTrue(moveSuccess)
        
        // Verify note is inside the folder
        let folderNotes = storage.listNotesInFolder(userId: testUserId, folderId: folder.id)
        XCTAssertEqual(folderNotes.count, 1)
        XCTAssertEqual(folderNotes.first?.id, note.id)
        XCTAssertEqual(folderNotes.first?.folderId, folder.id)
    }
    
    func testSearchNotes() {
        _ = noteService.createNote(title: "Apple Pie Recipe", content: "Ingredients include apples and flour.", userId: testUserId)
        _ = noteService.createNote(title: "Banana Bread", content: "Bake a delicious banana loaf.", userId: testUserId)
        _ = noteService.createNote(title: "Shopping List", content: "Buy apples, milk, and eggs.", userId: testUserId)
        
        // Search for "apples" (should match "Apple Pie Recipe" and "Shopping List")
        let results = noteService.searchNotes(query: "apple", userId: testUserId)
        XCTAssertEqual(results.count, 2)
        
        let titles = results.map { $0.title }
        XCTAssertTrue(titles.contains("Apple Pie Recipe"))
        XCTAssertTrue(titles.contains("Shopping List"))
        XCTAssertFalse(titles.contains("Banana Bread"))
    }
    
    func testAutoDeleteEmptyNotes() {
        // Create non-empty note
        _ = noteService.createNote(title: "Important", content: "Something", userId: testUserId)
        
        // Create empty note (Untitled with no content)
        _ = noteService.createNote(title: "Untitled", content: "", userId: testUserId)
        
        // Create another empty note
        _ = noteService.createNote(title: "", content: "   ", userId: testUserId)
        
        XCTAssertEqual(storage.listActiveNotes(userId: testUserId).count, 3)
        
        // Run auto-delete empty notes
        noteService.autoDeleteEmptyNotes(userId: testUserId)
        
        // Should only have 1 note left (the non-empty one)
        let remaining = storage.listActiveNotes(userId: testUserId)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Important")
    }
}
