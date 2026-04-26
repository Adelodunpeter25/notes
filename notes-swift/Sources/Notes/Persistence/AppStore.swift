import Foundation
import SQLite3

/// Central observable store backed by SQLite.
/// Views read from @Published arrays; mutations go through upsert/delete methods.
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var notes: [Note] = []
    @Published var folders: [Folder] = []
    @Published var tasks: [NoteTask] = []

    private var db: OpaquePointer?
    private let iso = ISO8601DateFormatter()

    init() {
        openDatabase()
        createTables()
        loadAll()
    }

    // MARK: - Setup

    private func openDatabase() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sqlite3_open(dir.appendingPathComponent("notes.sqlite").path, &db)
    }

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY, user_id TEXT, folder_id TEXT,
                title TEXT NOT NULL DEFAULT 'Untitled',
                content TEXT NOT NULL DEFAULT '',
                is_pinned INTEGER NOT NULL DEFAULT 0,
                created_at TEXT, updated_at TEXT, deleted_at TEXT
            );
            CREATE TABLE IF NOT EXISTS folders (
                id TEXT PRIMARY KEY, user_id TEXT, name TEXT NOT NULL,
                created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY, user_id TEXT,
                title TEXT NOT NULL DEFAULT 'Untitled',
                description TEXT NOT NULL DEFAULT '',
                is_completed INTEGER NOT NULL DEFAULT 0,
                due_date TEXT, created_at TEXT, updated_at TEXT, deleted_at TEXT
            );
        """)
    }

    func loadAll() {
        notes = fetchNotes()
        folders = fetchFolders()
        tasks = fetchTasks()
    }

    // MARK: - Notes

    private func fetchNotes() -> [Note] {
        var result: [Note] = []
        query("SELECT id,user_id,folder_id,title,content,is_pinned,created_at,updated_at,deleted_at FROM notes WHERE deleted_at IS NULL ORDER BY is_pinned DESC, updated_at DESC") { stmt in
            result.append(Note(
                id: col(stmt, 0), userId: optCol(stmt, 1), folderId: optCol(stmt, 2),
                title: col(stmt, 3), content: col(stmt, 4),
                isPinned: sqlite3_column_int(stmt, 5) != 0,
                createdAt: dateCol(stmt, 6), updatedAt: dateCol(stmt, 7),
                deletedAt: optDateCol(stmt, 8)
            ))
        }
        return result
    }

    func upsertNote(_ note: Note) {
        prepare("""
            INSERT INTO notes (id,user_id,folder_id,title,content,is_pinned,created_at,updated_at,deleted_at)
            VALUES (?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
              folder_id=excluded.folder_id, title=excluded.title, content=excluded.content,
              is_pinned=excluded.is_pinned, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at
            WHERE excluded.updated_at > notes.updated_at
        """) { stmt in
            bind(stmt, 1, note.id); bindOpt(stmt, 2, note.userId); bindOpt(stmt, 3, note.folderId)
            bind(stmt, 4, note.title); bind(stmt, 5, note.content)
            sqlite3_bind_int(stmt, 6, note.isPinned ? 1 : 0)
            bind(stmt, 7, iso.string(from: note.createdAt))
            bind(stmt, 8, iso.string(from: note.updatedAt))
            bindOpt(stmt, 9, note.deletedAt.map { iso.string(from: $0) })
            sqlite3_step(stmt)
        }
        notes = fetchNotes()
    }

    func softDeleteNote(id: String) {
        let now = iso.string(from: Date())
        exec("UPDATE notes SET deleted_at='\(now)', updated_at='\(now)' WHERE id='\(id)'")
        notes = fetchNotes()
    }

    // MARK: - Folders

    private func fetchFolders() -> [Folder] {
        var result: [Folder] = []
        query("SELECT id,user_id,name,created_at,updated_at FROM folders ORDER BY updated_at DESC") { stmt in
            result.append(Folder(
                id: col(stmt, 0), userId: optCol(stmt, 1), name: col(stmt, 2),
                createdAt: dateCol(stmt, 3), updatedAt: dateCol(stmt, 4)
            ))
        }
        return result
    }

    func upsertFolder(_ folder: Folder) {
        prepare("""
            INSERT INTO folders (id,user_id,name,created_at,updated_at) VALUES (?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET name=excluded.name, updated_at=excluded.updated_at
            WHERE excluded.updated_at > folders.updated_at
        """) { stmt in
            bind(stmt, 1, folder.id); bindOpt(stmt, 2, folder.userId); bind(stmt, 3, folder.name)
            bind(stmt, 4, iso.string(from: folder.createdAt))
            bind(stmt, 5, iso.string(from: folder.updatedAt))
            sqlite3_step(stmt)
        }
        folders = fetchFolders()
    }

    func deleteFolder(id: String) {
        exec("DELETE FROM folders WHERE id='\(id)'")
        folders = fetchFolders()
    }

    // MARK: - Tasks

    private func fetchTasks() -> [NoteTask] {
        var result: [NoteTask] = []
        query("SELECT id,user_id,title,description,is_completed,due_date,created_at,updated_at,deleted_at FROM tasks WHERE deleted_at IS NULL ORDER BY updated_at DESC") { stmt in
            result.append(NoteTask(
                id: col(stmt, 0), userId: optCol(stmt, 1),
                title: col(stmt, 2), taskDescription: col(stmt, 3),
                isCompleted: sqlite3_column_int(stmt, 4) != 0,
                dueDate: optDateCol(stmt, 5),
                createdAt: dateCol(stmt, 6), updatedAt: dateCol(stmt, 7),
                deletedAt: optDateCol(stmt, 8)
            ))
        }
        return result
    }

    func upsertTask(_ task: NoteTask) {
        prepare("""
            INSERT INTO tasks (id,user_id,title,description,is_completed,due_date,created_at,updated_at,deleted_at)
            VALUES (?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
              title=excluded.title, description=excluded.description,
              is_completed=excluded.is_completed, due_date=excluded.due_date,
              updated_at=excluded.updated_at, deleted_at=excluded.deleted_at
            WHERE excluded.updated_at > tasks.updated_at
        """) { stmt in
            bind(stmt, 1, task.id); bindOpt(stmt, 2, task.userId)
            bind(stmt, 3, task.title); bind(stmt, 4, task.taskDescription)
            sqlite3_bind_int(stmt, 5, task.isCompleted ? 1 : 0)
            bindOpt(stmt, 6, task.dueDate.map { iso.string(from: $0) })
            bind(stmt, 7, iso.string(from: task.createdAt))
            bind(stmt, 8, iso.string(from: task.updatedAt))
            bindOpt(stmt, 9, task.deletedAt.map { iso.string(from: $0) })
            sqlite3_step(stmt)
        }
        tasks = fetchTasks()
    }

    // MARK: - SQLite helpers

    private func exec(_ sql: String) { sqlite3_exec(db, sql, nil, nil, nil) }

    private func query(_ sql: String, _ block: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW { block(stmt) }
        }
        sqlite3_finalize(stmt)
    }

    private func prepare(_ sql: String, _ block: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK { block(stmt) }
        sqlite3_finalize(stmt)
    }

    private func col(_ s: OpaquePointer?, _ i: Int32) -> String {
        sqlite3_column_text(s, i).map { String(cString: $0) } ?? ""
    }
    private func optCol(_ s: OpaquePointer?, _ i: Int32) -> String? {
        guard sqlite3_column_type(s, i) != SQLITE_NULL else { return nil }
        return sqlite3_column_text(s, i).map { String(cString: $0) }
    }
    private func dateCol(_ s: OpaquePointer?, _ i: Int32) -> Date {
        iso.date(from: col(s, i)) ?? Date()
    }
    private func optDateCol(_ s: OpaquePointer?, _ i: Int32) -> Date? {
        optCol(s, i).flatMap { iso.date(from: $0) }
    }
    private func bind(_ s: OpaquePointer?, _ i: Int32, _ v: String) {
        sqlite3_bind_text(s, i, (v as NSString).utf8String, -1, nil)
    }
    private func bindOpt(_ s: OpaquePointer?, _ i: Int32, _ v: String?) {
        if let v = v { bind(s, i, v) } else { sqlite3_bind_null(s, i) }
    }
}
