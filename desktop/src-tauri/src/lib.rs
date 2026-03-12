use tauri_plugin_sql::{Migration, MigrationKind};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let migrations = vec![
        Migration {
            version: 1,
            description: "initialize schema",
            sql: "
                CREATE TABLE notes (
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
                CREATE INDEX idx_notes_folder ON notes(folder_id);
                CREATE INDEX idx_notes_updated ON notes(updated_at DESC);
                CREATE INDEX idx_notes_pinned_updated ON notes(is_pinned DESC, updated_at DESC);

                CREATE TABLE folders (
                  id TEXT PRIMARY KEY NOT NULL,
                  user_id TEXT,
                  name TEXT NOT NULL,
                  created_at TEXT,
                  updated_at TEXT,
                  deleted_at TEXT,
                  dirty INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX idx_folders_updated ON folders(updated_at DESC);

                CREATE TABLE tasks (
                  id TEXT PRIMARY KEY NOT NULL,
                  user_id TEXT,
                  title TEXT NOT NULL DEFAULT 'Untitled',
                  description TEXT NOT NULL DEFAULT '',
                  is_completed INTEGER NOT NULL DEFAULT 0,
                  due_date TEXT,
                  created_at TEXT,
                  updated_at TEXT,
                  deleted_at TEXT,
                  dirty INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX idx_tasks_updated ON tasks(updated_at DESC);

                CREATE TABLE sync_outbox (
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
                CREATE INDEX idx_sync_outbox_created ON sync_outbox(created_at ASC);
            ",
            kind: MigrationKind::Up,
        }
        ,
        Migration {
            version: 2,
            description: "sync state table",
            sql: "
                CREATE TABLE IF NOT EXISTS sync_state (
                  key TEXT PRIMARY KEY NOT NULL,
                  value TEXT
                );
            ",
            kind: MigrationKind::Up,
        }
    ];

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(
            tauri_plugin_sql::Builder::default()
                .add_migrations("sqlite:notes.db", migrations)
                .build(),
        )
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
