import * as SQLite from "expo-sqlite";

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

async function initialize(db: SQLite.SQLiteDatabase) {
  await db.execAsync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT,
      folder_id TEXT,
      title TEXT NOT NULL DEFAULT 'Untitled',
      content TEXT NOT NULL DEFAULT '',
      is_pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT,
      deleted_at TEXT,
      dirty INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id);
    CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_notes_pinned_updated ON notes(is_pinned DESC, updated_at DESC);

    CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
      title,
      content,
      content='notes',
      content_rowid='rowid',
      tokenize='unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
      INSERT INTO notes_fts(rowid, title, content)
      VALUES (new.rowid, new.title, new.content);
    END;

    CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
      INSERT INTO notes_fts(notes_fts, rowid, title, content)
      VALUES('delete', old.rowid, old.title, old.content);
    END;

    CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
      INSERT INTO notes_fts(notes_fts, rowid, title, content)
      VALUES('delete', old.rowid, old.title, old.content);
      INSERT INTO notes_fts(rowid, title, content)
      VALUES (new.rowid, new.title, new.content);
    END;

    CREATE TABLE IF NOT EXISTS folders (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT,
      name TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      deleted_at TEXT,
      dirty INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_folders_updated ON folders(updated_at DESC);

    CREATE TABLE IF NOT EXISTS sync_outbox (
      op_id TEXT PRIMARY KEY NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      op_type TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      base_server_version INTEGER,
      created_at TEXT NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      next_retry_at TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_sync_outbox_created ON sync_outbox(created_at ASC);

    CREATE TABLE IF NOT EXISTS sync_state (
      user_id TEXT PRIMARY KEY NOT NULL,
      last_notes_cursor TEXT,
      last_folders_cursor TEXT,
      last_full_sync_at TEXT
    );

    INSERT INTO notes_fts(notes_fts) VALUES('rebuild');
  `);
}

export async function getLocalDatabase() {
  if (!dbPromise) {
    dbPromise = (async () => {
      const db = await SQLite.openDatabaseAsync("notes_local.db");
      await initialize(db);
      return db;
    })();
  }

  return dbPromise;
}

export async function initializeLocalDatabase() {
  await getLocalDatabase();
}
