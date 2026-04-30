mod commands;
mod db;
mod error;
mod models;

use commands::*;
use tauri::Manager;
use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState};

#[tauri::command]
fn open_in_quick_note(app: tauri::AppHandle, note_id: Option<String>) {
    if let Some(win) = app.get_webview_window("quick-note") {
        if let Some(id) = note_id {
            let base = win.url().unwrap();
            let url = base
                .join(&format!("quick-note.html?noteId={}", id))
                .unwrap();
            let _ = win.navigate(url);
        }
        let _ = win.show();
        let _ = win.set_focus();
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .setup(|app| {
            db::init_db(&app.handle())?;

            let handle = app.handle().clone();
            let shortcut = Shortcut::new(Some(Modifiers::META | Modifiers::SHIFT), Code::KeyN);
            app.global_shortcut()
                .on_shortcut(shortcut, move |_app, _shortcut, event| {
                    if event.state() != ShortcutState::Pressed {
                        return;
                    }
                    if let Some(win) = handle.get_webview_window("quick-note") {
                        if win.is_visible().unwrap_or(false) {
                            let _ = win.hide();
                        } else {
                            let _ = win.show();
                            let _ = win.set_focus();
                        }
                    }
                })?;

            // Hide main window instead of closing (keeps tray icon alive)
            let main_win = app.get_webview_window("main").unwrap();
            let main_win_clone = main_win.clone();
            main_win.on_window_event(move |event| {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                    let _ = main_win_clone.hide();
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            list_notes,
            get_note_counts,
            get_note,
            create_note,
            update_note,
            delete_note,
            list_folders,
            get_folder,
            create_folder,
            rename_folder,
            delete_folder,
            list_tasks,
            get_task,
            create_task,
            update_task,
            toggle_task,
            delete_task,
            list_trash,
            restore_note,
            permanently_delete_note,
            clear_trash,
            open_in_quick_note,
            upsert_note,
            upsert_folder,
            upsert_task,
            list_deleted_tasks,
            get_scratch_pad,
            save_scratch_pad,
            get_sync_cursor,
            save_sync_cursor,
            clear_sync_cursor,
            get_device_identifier,
        ])
        .build(tauri::generate_context!())
        .expect("error while building tauri application");

    app.run(|app, event| {
        if let tauri::RunEvent::Reopen {
            has_visible_windows,
            ..
        } = event
        {
            if !has_visible_windows {
                if let Some(win) = app.get_webview_window("main") {
                    let _ = win.show();
                    let _ = win.set_focus();
                }
            }
        }
    });
}
