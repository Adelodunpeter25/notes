use tauri::{AppHandle, command};
use uuid::Uuid;
use chrono::Utc;
use rusqlite::params;

use crate::db::DbState;
use tauri::Manager;
use crate::error::Result;
use crate::models::{Task, CreateTaskPayload, UpdateTaskPayload};

#[command]
pub fn list_tasks(app: AppHandle, q: Option<String>) -> Result<Vec<Task>> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let mut query = "SELECT id, user_id, title, description, is_completed, due_date, created_at, updated_at 
                     FROM tasks 
                     WHERE deleted_at IS NULL".to_string();
    
    let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = vec![];
    
    if let Some(search) = q {
        query.push_str(" AND (title LIKE ? OR description LIKE ?)");
        let search_pattern = format!("%{}%", search);
        params_vec.push(Box::new(search_pattern.clone()));
        params_vec.push(Box::new(search_pattern));
    }
    
    query.push_str(" ORDER BY is_completed ASC, updated_at DESC");
    
    let mut stmt = db.prepare(&query).map_err(|e| crate::error::AppError {
        message: format!("Failed to prepare statement: {}", e),
    })?;
    
    let params_refs: Vec<&dyn rusqlite::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();
    
    let tasks = stmt
        .query_map(params_refs.as_slice(), |row| {
            Ok(Task {
                id: row.get(0)?,
                user_id: row.get(1)?,
                title: row.get(2)?,
                description: row.get(3)?,
                is_completed: row.get(4)?,
                due_date: row.get(5)?,
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
    
    Ok(tasks)
}

/// Internal helper — fetches a task using an already-open connection reference.
/// This avoids a mutex deadlock when called from within a command that already
/// holds the DbState lock.
fn fetch_task_by_id(db: &rusqlite::Connection, id: &str) -> Result<Task> {
    let mut stmt = db
        .prepare("SELECT id, user_id, title, description, is_completed, due_date, created_at, updated_at 
                  FROM tasks 
                  WHERE id = ? AND deleted_at IS NULL")
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

    let task = stmt
        .query_row(params![id], |row| {
            Ok(Task {
                id: row.get(0)?,
                user_id: row.get(1)?,
                title: row.get(2)?,
                description: row.get(3)?,
                is_completed: row.get(4)?,
                due_date: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                deleted_at: None,
            })
        })
        .map_err(|_| crate::error::AppError {
            message: format!("Task not found: {}", id),
        })?;

    Ok(task)
}

#[command]
pub fn get_task(app: AppHandle, id: String) -> Result<Task> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    fetch_task_by_id(&db, &id)
}

#[command]
pub fn create_task(
    app: AppHandle,
    payload: CreateTaskPayload,
) -> Result<Task> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    
    db.execute(
        "INSERT INTO tasks (id, title, description, is_completed, due_date, created_at, updated_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?)",
        params![
            id.clone(),
            payload.title,
            payload.description,
            false,
            payload.due_date,
            now.clone(),
            now,
        ],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to create task: {}", e),
    })?;
    
    // Use the helper to avoid re-acquiring the mutex lock
    fetch_task_by_id(&db, &id)
}

#[command]
pub fn update_task(
    app: AppHandle,
    id: String,
    payload: UpdateTaskPayload,
) -> Result<Task> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let now = Utc::now().to_rfc3339();
    let mut updates = vec![];
    let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = vec![];
    
    if let Some(title) = payload.title {
        updates.push("title = ?");
        params_vec.push(Box::new(title));
    }
    
    if let Some(description) = payload.description {
        updates.push("description = ?");
        params_vec.push(Box::new(description));
    }
    
    if let Some(is_completed) = payload.is_completed {
        updates.push("is_completed = ?");
        params_vec.push(Box::new(is_completed));
    }
    
    if let Some(due_date) = payload.due_date {
        updates.push("due_date = ?");
        params_vec.push(Box::new(due_date));
    }
    
    if updates.is_empty() {
        return fetch_task_by_id(&db, &id);
    }
    
    updates.push("updated_at = ?");
    params_vec.push(Box::new(now));
    params_vec.push(Box::new(id.clone()));
    
    let query = format!(
        "UPDATE tasks SET {} WHERE id = ? AND deleted_at IS NULL",
        updates.join(", ")
    );
    
    let params_refs: Vec<&dyn rusqlite::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();
    
    db.execute(&query, params_refs.as_slice())
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to update task: {}", e),
        })?;
    
    // Use the helper to avoid re-acquiring the mutex lock
    fetch_task_by_id(&db, &id)
}

#[command]
pub fn toggle_task(app: AppHandle, id: String) -> Result<Task> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let now = Utc::now().to_rfc3339();
    
    db.execute(
        "UPDATE tasks 
         SET is_completed = NOT is_completed, updated_at = ? 
         WHERE id = ? AND deleted_at IS NULL",
        params![now, id.clone()],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to toggle task: {}", e),
    })?;
    
    // Use the helper to avoid re-acquiring the mutex lock
    fetch_task_by_id(&db, &id)
}

#[command]
pub fn delete_task(app: AppHandle, id: String) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();
    
    let now = Utc::now().to_rfc3339();
    
    db.execute(
        "UPDATE tasks SET deleted_at = ? WHERE id = ?",
        params![now, id],
    )
    .map_err(|e| crate::error::AppError {
        message: format!("Failed to delete task: {}", e),
    })?;
    
    Ok(())
}

#[command]
pub fn upsert_task(app: AppHandle, task: crate::models::Task) -> Result<()> {
    let db_state = app.state::<DbState>();
    let db = db_state.0.lock().unwrap();

    db.execute(
        "INSERT INTO tasks (id, user_id, title, description, is_completed, due_date, created_at, updated_at, deleted_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
         ON CONFLICT(id) DO UPDATE SET
           title = excluded.title,
           description = excluded.description,
           is_completed = excluded.is_completed,
           due_date = excluded.due_date,
           updated_at = excluded.updated_at,
           deleted_at = excluded.deleted_at
         WHERE excluded.updated_at > tasks.updated_at",
        params![
            task.id,
            task.user_id,
            task.title,
            task.description,
            task.is_completed,
            task.due_date,
            task.created_at,
            task.updated_at,
            task.deleted_at,
        ],
    ).map_err(|e| crate::error::AppError { message: format!("upsert_task failed: {}", e) })?;

    Ok(())
}
