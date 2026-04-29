import { getDb } from "../client";
import { getNote } from "./noteRepo";
import type { Note } from "@shared/notes";

function rowToNote(row: any): Note {
  return {
    id: row.id,
    userId: row.user_id ?? undefined,
    folderId: row.folder_id ?? undefined,
    title: row.title,
    content: row.content,
    isPinned: row.is_pinned === 1,
    createdAt: row.created_at ?? undefined,
    updatedAt: row.updated_at ?? undefined,
    deletedAt: row.deleted_at ?? undefined,
  };
}

export async function listTrash(): Promise<Note[]> {
  const db = getDb();
  const rows = await db.getAllAsync(
    `SELECT * FROM notes
     WHERE deleted_at IS NOT NULL
     AND NOT (
       (title = '' OR title = 'Untitled')
       AND (content = '' OR content = '<p></p>')
       AND is_pinned = 0
     )
     ORDER BY deleted_at DESC`,
  );
  return rows.map(rowToNote);
}

export async function restoreNote(id: string): Promise<Note> {
  const db = getDb();
  const now = new Date().toISOString();
  await db.runAsync("UPDATE notes SET deleted_at = NULL, updated_at = ? WHERE id = ?", [now, id]);
  return getNote(id);
}

export async function permanentlyDeleteNote(id: string): Promise<void> {
  const db = getDb();
  await db.runAsync("DELETE FROM notes WHERE id = ?", [id]);
}

export async function clearTrash(): Promise<void> {
  const db = getDb();
  await db.runAsync("DELETE FROM notes WHERE deleted_at IS NOT NULL");
}
