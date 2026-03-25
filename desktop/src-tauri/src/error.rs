use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct AppError {
    pub message: String,
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for AppError {}

impl From<tauri_plugin_sql::Error> for AppError {
    fn from(err: tauri_plugin_sql::Error) -> Self {
        AppError {
            message: format!("Database error: {}", err),
        }
    }
}

pub type Result<T> = std::result::Result<T, AppError>;
