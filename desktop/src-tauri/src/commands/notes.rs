use chrono::Utc;
use rusqlite::params;
use tauri::{command, AppHandle, Manager};
use uuid::Uuid;

use crate::db::DbState;
use crate::error::Result;
use crate::models::{CreateNotePayload, Note, UpdateNotePayload};

#[command]
pub fn list_notes(
    app: AppHandle,
    folder_id: Option<String>,
    q: Option<String>,
) -> Result<Vec<Note>> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    let mut query =
        "SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at 
                     FROM notes 
                     WHERE deleted_at IS NULL"
            .to_string();

    let mut conditions = vec![];

    if folder_id.is_some() {
        conditions.push("folder_id = ?");
    }

    if q.is_some() {
        conditions.push("(title LIKE ? OR content LIKE ?)");
    }

    if !conditions.is_empty() {
        query.push_str(" AND ");
        query.push_str(&conditions.join(" AND "));
    }

    query.push_str(" ORDER BY is_pinned DESC, updated_at DESC");

    let mut stmt = db.prepare(&query).map_err(|e| crate::error::AppError {
        message: format!("Failed to prepare statement: {}", e),
    })?;

    let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = vec![];

    if let Some(fid) = folder_id {
        params_vec.push(Box::new(fid));
    }

    if let Some(search) = q {
        let search_pattern = format!("%{}%", search);
        params_vec.push(Box::new(search_pattern.clone()));
        params_vec.push(Box::new(search_pattern));
    }

    let params_refs: Vec<&dyn rusqlite::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();

    let notes = stmt
        .query_map(params_refs.as_slice(), |row| {
            Ok(Note {
                id: row.get(0)?,
                user_id: row.get(1)?,
                folder_id: row.get(2)?,
                title: row.get(3)?,
                content: row.get(4)?,
                is_pinned: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: None,
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
pub fn get_note(app: AppHandle, id: String) -> Result<Note> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    let mut stmt = db
        .prepare(
            "SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at 
                  FROM notes 
                  WHERE id = ? AND deleted_at IS NULL",
        )
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

    let note = stmt
        .query_row(params![id.clone()], |row| {
            Ok(Note {
                id: row.get(0)?,
                user_id: row.get(1)?,
                folder_id: row.get(2)?,
                title: row.get(3)?,
                content: row.get(4)?,
                is_pinned: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: None,
            })
        })
        .map_err(|_| crate::error::AppError {
            message: format!("Note not found: {}", id),
        })?;

    Ok(note)
}

#[command]
pub fn create_note(app: AppHandle, payload: CreateNotePayload) -> Result<Note> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();

    db.execute(
        "INSERT INTO notes (id, folder_id, title, content, is_pinned, created_at, updated_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?)",
        params![
            id.clone(),
            payload.folder_id,
            payload.title,
            payload.content,
            payload.is_pinned,
            now.clone(),
            now,
        ],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to create note: {}", e),
    })?;

    db.query_row(
        "SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at 
         FROM notes WHERE id = ?",
        params![id],
        |row| {
            Ok(Note {
                id: row.get(0)?,
                user_id: row.get(1)?,
                folder_id: row.get(2)?,
                title: row.get(3)?,
                content: row.get(4)?,
                is_pinned: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: None,
            })
        },
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to fetch created note: {}", e),
    })
}

#[command]
pub fn update_note(app: AppHandle, id: String, payload: UpdateNotePayload) -> Result<Note> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    let now = Utc::now().to_rfc3339();
    let mut updates = vec![];
    let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = vec![];

    if let Some(folder_id) = payload.folder_id {
        updates.push("folder_id = ?");
        params_vec.push(Box::new(folder_id));
    }

    if let Some(title) = payload.title {
        updates.push("title = ?");
        params_vec.push(Box::new(title));
    }

    if let Some(content) = payload.content {
        updates.push("content = ?");
        params_vec.push(Box::new(content));
    }

    if let Some(is_pinned) = payload.is_pinned {
        updates.push("is_pinned = ?");
        params_vec.push(Box::new(is_pinned));
    }

    if !updates.is_empty() {
        updates.push("updated_at = ?");
        params_vec.push(Box::new(now));
        params_vec.push(Box::new(id.clone()));

        let query = format!(
            "UPDATE notes SET {} WHERE id = ? AND deleted_at IS NULL",
            updates.join(", ")
        );

        let params_refs: Vec<&dyn rusqlite::ToSql> =
            params_vec.iter().map(|p| p.as_ref()).collect();

        db.execute(&query, params_refs.as_slice())
            .map_err(|e| crate::error::AppError {
                message: format!("Failed to update note: {}", e),
            })?;
    }

    db.query_row(
        "SELECT id, user_id, folder_id, title, content, is_pinned, created_at, updated_at 
         FROM notes WHERE id = ? AND deleted_at IS NULL",
        params![id],
        |row| {
            Ok(Note {
                id: row.get(0)?,
                user_id: row.get(1)?,
                folder_id: row.get(2)?,
                title: row.get(3)?,
                content: row.get(4)?,
                is_pinned: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: None,
            })
        },
    )
    .map_err(|_| crate::error::AppError {
        message: format!("Note not found: {}", id),
    })
}

#[command]
pub fn delete_note(app: AppHandle, id: String) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    let now = Utc::now().to_rfc3339();

    db.execute(
        "UPDATE notes SET deleted_at = ? WHERE id = ?",
        params![now, id],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to delete note: {}", e),
    })?;

    Ok(())
}

#[command]
pub fn upsert_note(app: AppHandle, note: Note) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    db.execute(
        "INSERT INTO notes (id, user_id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
         ON CONFLICT(id) DO UPDATE SET
           folder_id = excluded.folder_id,
           title = excluded.title,
           content = excluded.content,
           is_pinned = excluded.is_pinned,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at
         WHERE datetime(excluded.updated_at) > datetime(notes.updated_at)",
        params![
            note.id,
            note.user_id,
            note.folder_id,
            note.title,
            note.content,
            note.is_pinned,
            note.created_at,
            note.updated_at,
            note.deleted_at,
        ],
    ).map_err(|e| crate::error::AppError { message: format!("upsert_note failed: {}", e) })?;

    Ok(())
}
