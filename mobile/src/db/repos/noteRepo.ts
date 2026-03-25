import "react-native-get-random-values";
import { v4 as uuidv4 } from "uuid";
import { getDb } from "../client";
import type { Note, CreateNotePayload, UpdateNotePayload } from "@shared/notes";

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

export async function listNotes(params?: { folderId?: string; q?: string }): Promise<Note[]> {
  const db = getDb();
  let sql = "SELECT * FROM notes WHERE deleted_at IS NULL";
  const args: any[] = [];

  if (params?.folderId) {
    sql += " AND folder_id = ?";
    args.push(params.folderId);
  }
  if (params?.q) {
    sql += " AND (title LIKE ? OR content LIKE ?)";
    const pattern = `%${params.q}%`;
    args.push(pattern, pattern);
  }

  sql += " ORDER BY is_pinned DESC, updated_at DESC";
  const rows = await db.getAllAsync(sql, args);
  return rows.map(rowToNote);
}

export async function getNote(id: string): Promise<Note> {
  const db = getDb();
  const row = await db.getFirstAsync(
    "SELECT * FROM notes WHERE id = ? AND deleted_at IS NULL",
    [id],
  );
  if (!row) throw new Error(`Note not found: ${id}`);
  return rowToNote(row);
}

export async function createNote(payload: CreateNotePayload): Promise<Note> {
  const db = getDb();
  const id = uuidv4();
  const now = new Date().toISOString();

  await db.runAsync(
    "INSERT INTO notes (id, folder_id, title, content, is_pinned, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [id, payload.folderId ?? null, payload.title, payload.content, payload.isPinned ? 1 : 0, now, now],
  );
  return getNote(id);
}

export async function updateNote(id: string, payload: UpdateNotePayload): Promise<Note> {
  const db = getDb();
  const now = new Date().toISOString();
  const sets: string[] = [];
  const args: any[] = [];

  if (payload.folderId !== undefined) { sets.push("folder_id = ?"); args.push(payload.folderId); }
  if (payload.title !== undefined) { sets.push("title = ?"); args.push(payload.title); }
  if (payload.content !== undefined) { sets.push("content = ?"); args.push(payload.content); }
  if (payload.isPinned !== undefined) { sets.push("is_pinned = ?"); args.push(payload.isPinned ? 1 : 0); }

  if (sets.length > 0) {
    sets.push("updated_at = ?");
    args.push(now, id);
    await db.runAsync(
      `UPDATE notes SET ${sets.join(", ")} WHERE id = ? AND deleted_at IS NULL`,
      args,
    );
  }
  return getNote(id);
}

export async function deleteNote(id: string): Promise<void> {
  const db = getDb();
  const now = new Date().toISOString();
  await db.runAsync("UPDATE notes SET deleted_at = ? WHERE id = ?", [now, id]);
}
