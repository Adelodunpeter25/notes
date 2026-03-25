use tauri::{AppHandle, command};
use uuid::Uuid;
use chrono::Utc;
use rusqlite::params;

use crate::db::DbState;
use tauri::Manager;
use crate::error::Result;
use crate::models::{Folder, CreateFolderPayload, RenameFolderPayload};

#[command]
pub fn list_folders(app: AppHandle) -> Result<Vec<Folder>> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let mut stmt = db
        .prepare("SELECT f.id, f.user_id, f.name, f.created_at, f.updated_at,
                  COUNT(n.id) as notes_count
                  FROM folders f
                  LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
                  GROUP BY f.id
                  ORDER BY f.updated_at DESC")
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to prepare statement: {}", e),
        })?;
    
    let folders = stmt
        .query_map([], |row| {
            Ok(Folder {
                id: row.get(0)?,
                user_id: row.get(1)?,
                name: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
                notes_count: row.get(5)?,
            })
        })
        .map_err(|e| crate::error::AppError {
            message: format!("Query failed: {}", e),
        })?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to collect results: {}", e),
        })?;
    
    Ok(folders)
}

#[command]
pub fn get_folder(app: AppHandle, id: String) -> Result<Folder> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let mut stmt = db
        .prepare("SELECT f.id, f.user_id, f.name, f.created_at, f.updated_at,
                  COUNT(n.id) as notes_count
                  FROM folders f
                  LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
                  WHERE f.id = ?
                  GROUP BY f.id")
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to prepare statement: {}", e),
        })?;
    
    let folder = stmt
        .query_row(params![id.clone()], |row| {
            Ok(Folder {
                id: row.get(0)?,
                user_id: row.get(1)?,
                name: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
                notes_count: row.get(5)?,
            })
        })
        .map_err(|_| crate::error::AppError {
            message: format!("Folder not found: {}", id),
        })?;
    
    Ok(folder)
}

#[command]
pub fn create_folder(
    app: AppHandle,
    payload: CreateFolderPayload,
) -> Result<Folder> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    
    db.execute(
        "INSERT INTO folders (id, name, created_at, updated_at) 
         VALUES (?, ?, ?, ?)",
        params![id.clone(), payload.name, now.clone(), now],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to create folder: {}", e),
    })?;
    
    get_folder(app.clone(), id)
}

#[command]
pub fn rename_folder(
    app: AppHandle,
    id: String,
    payload: RenameFolderPayload,
) -> Result<Folder> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let now = Utc::now().to_rfc3339();
    
    db.execute(
        "UPDATE folders SET name = ?, updated_at = ? WHERE id = ?",
        params![payload.name, now, id.clone()],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to rename folder: {}", e),
    })?;
    
    get_folder(app.clone(), id)
}

#[command]
pub fn delete_folder(app: AppHandle, id: String) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    db.execute("DELETE FROM folders WHERE id = ?", params![id])
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to delete folder: {}", e),
        })?;
    
    Ok(())
}

#[command]
pub fn upsert_folder(app: AppHandle, folder: crate::models::Folder) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    db.execute(
        "INSERT INTO folders (id, user_id, name, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5)
         ON CONFLICT(id) DO UPDATE SET
           name = excluded.name,
           updated_at = excluded.updated_at
         WHERE excluded.updated_at > folders.updated_at",
        params![
            folder.id,
            folder.user_id,
            folder.name,
            folder.created_at,
            folder.updated_at,
        ],
    ).map_err(|e| crate::error::AppError { message: format!("upsert_folder failed: {}", e) })?;

    Ok(())
}
