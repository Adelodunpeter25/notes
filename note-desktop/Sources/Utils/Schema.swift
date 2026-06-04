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
    
    public static let allCreations = [
        createUsersTable,
        createFoldersTable,
        createNotesTable,
        createSyncOpsTable
    ]
}
