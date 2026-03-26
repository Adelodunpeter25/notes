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
}
