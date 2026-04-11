export const MIGRATIONS = [
  // v1 - initial schema
  `CREATE TABLE IF NOT EXISTS notes (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT,
    folder_id TEXT,
    title TEXT NOT NULL DEFAULT 'Untitled',
    content TEXT NOT NULL DEFAULT '',
    is_pinned INTEGER NOT NULL DEFAULT 0,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT
  )`,
  `CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id)`,
  `CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)`,
  `CREATE INDEX IF NOT EXISTS idx_notes_pinned_updated ON notes(is_pinned DESC, updated_at DESC)`,
  `CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes(deleted_at)`,

  `CREATE TABLE IF NOT EXISTS folders (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT,
    name TEXT NOT NULL,
    created_at TEXT,
    updated_at TEXT
  )`,
  `CREATE INDEX IF NOT EXISTS idx_folders_updated ON folders(updated_at DESC)`,

  `CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT,
    title TEXT NOT NULL DEFAULT 'Untitled',
    description TEXT NOT NULL DEFAULT '',
    is_completed INTEGER NOT NULL DEFAULT 0,
    due_date TEXT,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT
  )`,
  `CREATE INDEX IF NOT EXISTS idx_tasks_updated ON tasks(updated_at DESC)`,

  // v2 - sync_state table
  `CREATE TABLE IF NOT EXISTS sync_state (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT,
    device_id TEXT NOT NULL UNIQUE,
    last_cursor TEXT,
    last_sync_at TEXT,
    updated_at TEXT NOT NULL
  )`,
];
