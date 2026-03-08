import initSqlJs from "sql.js";
import wasmURL from "sql.js/dist/sql-wasm.wasm?url";

const DB_STORAGE_KEY = "notes_desktop_sqlite_db_v1";

type SQLiteStatic = {
  Database: new (data?: Uint8Array) => SQLiteDatabase;
};

type SQLiteStatement = {
  run: (params?: unknown[]) => void;
  free: () => void;
  bind: (params?: unknown[]) => void;
  step: () => boolean;
  getAsObject: () => Record<string, unknown>;
};

type SQLiteDatabase = {
  exec: (sql: string, params?: unknown[]) => Array<{ values: unknown[][] }>;
  run: (sql: string, params?: unknown[]) => void;
  export: () => Uint8Array;
  prepare: (sql: string) => SQLiteStatement;
};

let sqlitePromise: Promise<SQLiteStatic> | null = null;
let databasePromise: Promise<SQLiteDatabase> | null = null;

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 1) {
    binary += String.fromCharCode(bytes[index]);
  }
  return btoa(binary);
}

async function getSqlite() {
  if (!sqlitePromise) {
    sqlitePromise = initSqlJs({
      locateFile: () => wasmURL,
    }) as unknown as Promise<SQLiteStatic>;
  }

  return sqlitePromise;
}

function initializeSchema(db: SQLiteDatabase) {
  db.exec(`
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
  `);
}

export async function getLocalDatabase() {
  if (!databasePromise) {
    databasePromise = (async () => {
      const SQL = await getSqlite();
      if (!SQL) {
        throw new Error("Failed to initialize sql.js");
      }
      const saved = localStorage.getItem(DB_STORAGE_KEY);
      const db = saved
        ? new SQL.Database(base64ToUint8Array(saved))
        : new SQL.Database();

      initializeSchema(db);
      return db;
    })();
  }

  return databasePromise;
}

export async function persistDatabase() {
  const db = await getLocalDatabase();
  const bytes = db.export();
  localStorage.setItem(DB_STORAGE_KEY, uint8ArrayToBase64(bytes));
}

export async function initializeLocalDatabase() {
  await getLocalDatabase();
}
