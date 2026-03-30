use std::fs;
use tauri::{command, AppHandle, Manager};

use crate::error::Result;

fn scratch_pad_path(app: &AppHandle) -> Result<std::path::PathBuf> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| crate::error::AppError {
            message: format!("Failed to get app data dir: {}", e),
        })?;
    fs::create_dir_all(&dir).map_err(|e| crate::error::AppError {
        message: format!("Failed to create app data dir: {}", e),
    })?;
    Ok(dir.join("scratch-pad.txt"))
}

#[command]
pub fn get_scratch_pad(app: AppHandle) -> Result<String> {
    let path = scratch_pad_path(&app)?;
    match fs::read_to_string(&path) {
        Ok(content) => Ok(content),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(String::new()),
        Err(e) => Err(crate::error::AppError {
            message: format!("Failed to read scratch pad: {}", e),
        }),
    }
}

#[command]
pub fn save_scratch_pad(app: AppHandle, content: String) -> Result<()> {
    let path = scratch_pad_path(&app)?;
    fs::write(&path, &content).map_err(|e| crate::error::AppError {
        message: format!("Failed to save scratch pad: {}", e),
    })?;
    Ok(())
}
