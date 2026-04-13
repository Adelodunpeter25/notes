use crate::db::DbState;
use rusqlite::{params, OptionalExtension};
use tauri::State;
use uuid::Uuid;

fn get_device_id(conn: &rusqlite::Connection) -> Result<String, String> {
    // Try to get existing device ID
    let existing: Option<String> = conn
        .query_row("SELECT device_id FROM sync_state LIMIT 1", [], |row| row.get(0))
        .optional()
        .map_err(|e| e.to_string())?;

    if let Some(id) = existing {
        return Ok(id);
    }

    // None exists — seed one now
    let device_id = Uuid::new_v4().to_string();
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();
    conn.execute(
        "INSERT INTO sync_state (id, device_id, updated_at) VALUES (?1, ?2, ?3)",
        params![id, device_id, now],
    ).map_err(|e| e.to_string())?;

    Ok(device_id)
}

#[tauri::command]
pub fn get_sync_cursor(db: State<DbState>) -> Result<Option<String>, String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    let device_id = get_device_id(&conn)?;

    conn.query_row(
        "SELECT last_cursor FROM sync_state WHERE device_id = ? LIMIT 1",
        params![device_id],
        |row| row.get::<_, Option<String>>(0),
    )
    .optional()
    .map_err(|e| e.to_string())
    .map(|r| r.flatten())
}

#[tauri::command]
pub fn save_sync_cursor(
    cursor: String,
    user_id: Option<String>,
    db: State<DbState>,
) -> Result<(), String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    let device_id = get_device_id(&conn)?;
    let now = chrono::Utc::now().to_rfc3339();
    let id = Uuid::new_v4().to_string();

    conn.execute(
        "INSERT INTO sync_state (id, user_id, device_id, last_cursor, last_sync_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(device_id) DO UPDATE SET
           user_id = COALESCE(excluded.user_id, sync_state.user_id),
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
    let device_id = get_device_id(&conn)?;

    conn.execute(
        "UPDATE sync_state SET last_cursor = NULL WHERE device_id = ?1",
        params![device_id],
    )
    .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn get_device_identifier(db: State<DbState>) -> Result<String, String> {
    let conn = db.0.lock().map_err(|e| e.to_string())?;
    get_device_id(&conn)
}
