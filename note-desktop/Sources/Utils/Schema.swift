import Foundation

public struct Schema {
    public static let createUsersTable = """
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT,
        email TEXT UNIQUE
    );
    """
    
    public static let createFoldersTable = """
    CREATE TABLE IF NOT EXISTS folders (
        id TEXT PRIMARY KEY,
        name TEXT,
        userId TEXT,
        deletedAt TEXT
    );
    """
    
    public static let createNotesTable = """
    CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        isPinned INTEGER DEFAULT 0,
        folderId TEXT,
        userId TEXT,
        deletedAt TEXT
    );
    """
    
    public static let createSyncOpsTable = """
    CREATE TABLE IF NOT EXISTS sync_ops (
        id TEXT PRIMARY KEY,
        opType TEXT,
        entityType TEXT,
        entityId TEXT,
        payload TEXT,
        updatedAt TEXT
    );
    """
    
    public static let createNotesFtsTable = """
    CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(id UNINDEXED, title, content);
    """
    
    public static let createNotesFtsInsertTrigger = """
    CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts (id, title, content) VALUES (new.id, new.title, new.content);
    END;
    """
    
    public static let createNotesFtsUpdateTrigger = """
    CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
        UPDATE notes_fts SET title = new.title, content = new.content WHERE id = old.id;
    END;
    """
    
    public static let createNotesFtsDeleteTrigger = """
    CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
        DELETE FROM notes_fts WHERE id = old.id;
    END;
    """
    
    public static let allCreations = [
        createUsersTable,
        createFoldersTable,
        createNotesTable,
        createSyncOpsTable,
        createNotesFtsTable,
        createNotesFtsInsertTrigger,
        createNotesFtsUpdateTrigger,
        createNotesFtsDeleteTrigger
    ]
}
