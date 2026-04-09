mod commands;
mod db;
mod error;
mod models;

use commands::*;
use tauri::tray::TrayIconBuilder;
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

fn position_menu_bar_note(app: &tauri::AppHandle, icon_rect: tauri::Rect) {
    if let Some(win) = app.get_webview_window("menu-bar-note") {
        if let Ok(Some(monitor)) = win.current_monitor() {
            let scale = monitor.scale_factor();

            let win_width: u32 = 420;
            let win_height: u32 = 500;

            let icon_pos = icon_rect.position.to_physical::<i32>(scale);
            let icon_size = icon_rect.size.to_physical::<u32>(scale);

            let mut x = icon_pos.x + (icon_size.width as i32 / 2) - (win_width as i32 / 2);
            let y = icon_pos.y + icon_size.height as i32 + 4;

            let screen_width = monitor.size().width as i32;
            x = x.max(0).min(screen_width - win_width as i32);

            let _ = win.set_position(tauri::PhysicalPosition::new(x, y));
            let _ = win.set_size(tauri::PhysicalSize::new(win_width, win_height));
        }
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

            // Tray icon
            let icon = app.default_window_icon().unwrap().clone();

            let app_handle = app.handle().clone();
            TrayIconBuilder::new()
                .icon(icon)
                .tooltip("Notes - Scratch Pad")
                .show_menu_on_left_click(false)
                .on_tray_icon_event(move |_tray, event| {
                    if let tauri::tray::TrayIconEvent::Click {
                        button: tauri::tray::MouseButton::Left,
                        button_state: tauri::tray::MouseButtonState::Up,
                        rect,
                        ..
                    } = event
                    {
                        if let Some(win) = app_handle.get_webview_window("menu-bar-note") {
                            if win.is_visible().unwrap_or(false) {
                                let _ = win.hide();
                            } else {
                                position_menu_bar_note(&app_handle, rect);
                                let _ = win.show();
                                let _ = win.set_focus();
                            }
                        }
                    }
                })
                .build(app)?;

            // Hide menu-bar-note when it loses focus
            let app_handle2 = app.handle().clone();
            if let Some(win) = app.get_webview_window("menu-bar-note") {
                win.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        if let Some(w) = app_handle2.get_webview_window("menu-bar-note") {
                            if w.is_visible().unwrap_or(false) {
                                let _ = w.hide();
                            }
                        }
                    }
                });
            }

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
