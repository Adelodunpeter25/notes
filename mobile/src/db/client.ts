import * as SQLite from "expo-sqlite";
import { MIGRATIONS } from "./schema";

const DB_NAME = "notes.db";

let _db: SQLite.SQLiteDatabase | null = null;

export function getDb(): SQLite.SQLiteDatabase {
  if (!_db) {
    throw new Error("Database not initialized. Call initDb() first.");
  }
  return _db;
}

export async function initDb(): Promise<void> {
  _db = await SQLite.openDatabaseAsync(DB_NAME);
  await _db.execAsync("PRAGMA journal_mode = WAL;");
  await _db.execAsync(MIGRATIONS.join(";\n") + ";");

  // Runtime migrations for non-idempotent ALTER TABLE changes.
  // Keep this safe to re-run on every startup.
  const folderCols = await _db.getAllAsync<{ name: string }>("PRAGMA table_info(folders)");
  const hasDeletedAt = folderCols.some((c) => c.name === "deleted_at");
  if (!hasDeletedAt) {
    await _db.execAsync("ALTER TABLE folders ADD COLUMN deleted_at TEXT;");
    await _db.execAsync("CREATE INDEX IF NOT EXISTS idx_folders_deleted ON folders(deleted_at);");
  }
}
