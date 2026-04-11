use crate::db::DbState;
use rusqlite::{params, OptionalExtension};
use tauri::State;
use uuid::Uuid;

fn get_device_id() -> String {
    std::env::var("DEVICE_ID").unwrap_or_else(|_| Uuid::new_v4().to_string())
}

#[tauri::command]
pub fn get_sync_cursor(db: State<DbState>) -> Result<Option<String>, String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    let device_id = get_device_id();

    let mut stmt = conn
        .prepare("SELECT last_cursor FROM sync_state WHERE device_id = ? LIMIT 1")
        .map_err(|e| e.to_string())?;

    let result = stmt
        .query_row(params![device_id], |row| row.get::<_, Option<String>>(0))
        .optional()
        .map_err(|e| e.to_string())?;

    Ok(result.flatten())
}

#[tauri::command]
pub fn save_sync_cursor(
    cursor: String,
    user_id: String,
    db: State<DbState>,
) -> Result<(), String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    let device_id = get_device_id();
    let now = chrono::Utc::now().to_rfc3339();
    let id = Uuid::new_v4().to_string();

    conn.execute(
        "INSERT INTO sync_state (id, user_id, device_id, last_cursor, last_sync_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(device_id) DO UPDATE SET
           last_cursor = excluded.last_cursor,
           last_sync_at = excluded.last_sync_at,
           updated_at = excluded.updated_at",
        params![id, user_id, device_id, cursor, now, now],
    )
    .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn clear_sync_cursor(db: State<DbState>) -> Result<(), String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    let device_id = get_device_id();

    conn.execute("DELETE FROM sync_state WHERE device_id = ?1", params![device_id])
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn get_device_identifier() -> String {
    get_device_id()
}
