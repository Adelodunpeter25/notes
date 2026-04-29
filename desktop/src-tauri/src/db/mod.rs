use rusqlite::Connection;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Manager};

#[derive(Clone)]
pub struct DbState(pub Arc<Mutex<Connection>>);

pub fn init_db(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let app_dir = app.path().app_data_dir()?;
    std::fs::create_dir_all(&app_dir)?;
    let db_path = app_dir.join("notes.db");

    let conn = Connection::open(db_path)?;

    // Run migrations
    conn.execute(
        "CREATE TABLE IF NOT EXISTS notes (
          id TEXT PRIMARY KEY NOT NULL,
          user_id TEXT,
          folder_id TEXT,
          title TEXT NOT NULL DEFAULT 'Untitled',
          content TEXT NOT NULL DEFAULT '',
          is_pinned INTEGER NOT NULL DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        )",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id)",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_pinned_updated ON notes(is_pinned DESC, updated_at DESC)",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes(deleted_at)",
        [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS folders (
          id TEXT PRIMARY KEY NOT NULL,
          user_id TEXT,
          name TEXT NOT NULL,
          created_at TEXT,
          updated_at TEXT
        )",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_folders_updated ON folders(updated_at DESC)",
        [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS tasks (
          id TEXT PRIMARY KEY NOT NULL,
          user_id TEXT,
          title TEXT NOT NULL DEFAULT 'Untitled',
          description TEXT NOT NULL DEFAULT '',
          is_completed INTEGER NOT NULL DEFAULT 0,
          due_date TEXT,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        )",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_tasks_updated ON tasks(updated_at DESC)",
        [],
    )?;

    // Recreate sync_state if it has the old NOT NULL user_id constraint
    let needs_recreate: bool = conn
        .query_row(
            "SELECT COUNT(*) FROM pragma_table_info('sync_state') WHERE name='user_id' AND \"notnull\"=1",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0i64) > 0;

    if needs_recreate {
        conn.execute("DROP TABLE IF EXISTS sync_state", [])?;
    }

    conn.execute(
        "CREATE TABLE IF NOT EXISTS sync_state (
          id TEXT PRIMARY KEY NOT NULL,
          user_id TEXT,
          device_id TEXT NOT NULL UNIQUE,
          last_cursor TEXT,
          last_sync_at TEXT,
          updated_at TEXT NOT NULL
        )",
        [],
    )?;

    app.manage(DbState(Arc::new(Mutex::new(conn))));

    Ok(())
}
