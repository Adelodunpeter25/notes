use tauri::{AppHandle, command, Manager};
use rusqlite::params;

use crate::db::DbState;
use crate::error::Result;
use crate::models::Note;

#[command]
pub fn list_trash(app: AppHandle) -> Result<Vec<Note>> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let mut stmt = db
        .prepare("SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at 
                  FROM notes 
                  WHERE deleted_at IS NOT NULL
                  AND NOT (
                    (title = '' OR title = 'Untitled')
                    AND (content = '' OR content = '<p></p>')
                    AND is_pinned = 0
                  )
                  ORDER BY deleted_at DESC")
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to prepare statement: {}", e),
        })?;
    
    let notes = stmt
        .query_map([], |row| {
            Ok(Note {
                id: row.get(0)?,
                user_id: row.get(1)?,
                folder_id: row.get(2)?,
                title: row.get(3)?,
                content: row.get(4)?,
                is_pinned: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: row.get(8)?,
            })
        })
        .map_err(|e| crate::error::AppError {
            message: format!("Query failed: {}", e),
        })?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to collect results: {}", e),
        })?;
    
    Ok(notes)
}

#[command]
pub fn restore_note(app: AppHandle, id: String) -> Result<Note> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    db.execute(
        "UPDATE notes SET deleted_at = NULL WHERE id = ?",
        params![id.clone()],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to restore note: {}", e),
    })?;
    
    db.query_row(
        "SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at 
         FROM notes WHERE id = ?",
        params![id.clone()],
        |row| Ok(Note {
            id: row.get(0)?,
            user_id: row.get(1)?,
            folder_id: row.get(2)?,
            title: row.get(3)?,
            content: row.get(4)?,
            is_pinned: row.get(5)?,
            created_at: row.get(6)?,
            updated_at: row.get(7)?,
            deleted_at: row.get(8)?,
        }),
    ).map_err(|_| crate::error::AppError {
        message: format!("Note not found: {}", id),
    })
}

#[command]
pub fn permanently_delete_note(app: AppHandle, id: String) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    db.execute("DELETE FROM notes WHERE id = ?", params![id])
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to permanently delete note: {}", e),
        })?;
    
    Ok(())
}

#[command]
pub fn clear_trash(app: AppHandle) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    db.execute("DELETE FROM notes WHERE deleted_at IS NOT NULL", [])
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to clear trash: {}", e),
        })?;
    
    Ok(())
}
