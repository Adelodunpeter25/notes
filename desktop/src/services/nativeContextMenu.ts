import { Menu, type SubmenuOptions } from "@tauri-apps/api/menu";
import { LogicalPosition } from "@tauri-apps/api/dpi";
import { getCurrentWindow } from "@tauri-apps/api/window";

import type { Folder } from "@shared/folders";

type ShowNoteMenuOptions = {
  x: number;
  y: number;
  isPinned: boolean;
  folders: Folder[];
  currentFolderId?: string | null;
  onPinToggle: () => void;
  onMoveTo: (folderId: string) => void;
  onOpenInQuickNote: () => void;
  onDelete: () => void;
};

type ShowFolderMenuOptions = {
  x: number;
  y: number;
  onRename: () => void;
  onDelete: () => void;
};

const isDesktop =
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

export async function showNoteContextMenu({
  x,
  y,
  isPinned,
  folders,
  currentFolderId,
  onPinToggle,
  onMoveTo,
  onOpenInQuickNote,
  onDelete,
}: ShowNoteMenuOptions): Promise<void> {
  if (!isDesktop) {
    return;
  }

  const moveToSubmenu: SubmenuOptions = {
    text: "Move to",
    items: folders.length === 0
      ? [{ text: "No folders", enabled: false }]
      : folders.map((folder) => ({
          id: `move:${folder.id}`,
          text: folder.name,
          checked: folder.id === currentFolderId,
          action: () => onMoveTo(folder.id),
        })),
  };

  const menu = await Menu.new({
    items: [
      {
        id: "pin-toggle",
        text: isPinned ? "Unpin Note" : "Pin Note",
        action: onPinToggle,
      },
      moveToSubmenu,
      {
        id: "open-quick-note",
        text: "Open in Quick Note",
        action: onOpenInQuickNote,
      },
      {
        item: "Separator",
      },
      {
        id: "delete-note",
        text: "Delete",
        action: onDelete,
      },
    ],
  });

  await menu.popup(new LogicalPosition(x, y), getCurrentWindow());
  menu.close();
}

export async function showFolderContextMenu({
  x,
  y,
  onRename,
  onDelete,
}: ShowFolderMenuOptions): Promise<void> {
  if (!isDesktop) {
    return;
  }

  const menu = await Menu.new({
    items: [
      {
        id: "rename-folder",
        text: "Rename Folder",
        action: onRename,
      },
      {
        item: "Separator",
      },
      {
        id: "delete-folder",
        text: "Delete Folder",
        action: onDelete,
      },
    ],
  });

  await menu.popup(new LogicalPosition(x, y), getCurrentWindow());
  menu.close();
}
