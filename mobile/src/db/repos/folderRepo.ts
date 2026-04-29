import "react-native-get-random-values";
import { v4 as uuidv4 } from "uuid";
import { getDb } from "../client";
import type { Folder, CreateFolderPayload, RenameFolderPayload } from "@shared/folders";

function rowToFolder(row: any): Folder {
  return {
    id: row.id,
    userId: row.user_id ?? undefined,
    name: row.name,
    notesCount: Number(row.notes_count ?? 0),
    createdAt: row.created_at ?? undefined,
    updatedAt: row.updated_at ?? undefined,
    deletedAt: row.deleted_at ?? undefined,
  };
}

export async function listFolders(): Promise<Folder[]> {
  const db = getDb();
  const rows = await db.getAllAsync(
    `SELECT f.*, COUNT(n.id) as notes_count
     FROM folders f
     LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
     WHERE f.deleted_at IS NULL
     GROUP BY f.id
     ORDER BY f.updated_at DESC`,
  );
  return rows.map(rowToFolder);
}

export async function getFolder(id: string): Promise<Folder> {
  const db = getDb();
  const row = await db.getFirstAsync(
    `SELECT f.*, COUNT(n.id) as notes_count
     FROM folders f
     LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
     WHERE f.id = ? AND f.deleted_at IS NULL
     GROUP BY f.id`,
    [id],
  );
  if (!row) throw new Error(`Folder not found: ${id}`);
  return rowToFolder(row);
}

export async function createFolder(payload: CreateFolderPayload): Promise<Folder> {
  const db = getDb();
  const id = uuidv4();
  const now = new Date().toISOString();
  await db.runAsync(
    "INSERT INTO folders (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)",
    [id, payload.name, now, now],
  );
  return getFolder(id);
}

export async function renameFolder(id: string, payload: RenameFolderPayload): Promise<Folder> {
  const db = getDb();
  const now = new Date().toISOString();
  await db.runAsync(
    "UPDATE folders SET name = ?, updated_at = ? WHERE id = ?",
    [payload.name, now, id],
  );
  return getFolder(id);
}

export async function deleteFolder(id: string): Promise<void> {
  const db = getDb();
  // Soft delete — move notes to All Notes first, then mark folder deleted so it can sync.
  const now = new Date().toISOString();
  await db.runAsync("UPDATE notes SET folder_id = NULL, updated_at = ? WHERE folder_id = ?", [now, id]);
  await db.runAsync("UPDATE folders SET deleted_at = ?, updated_at = ? WHERE id = ?", [now, now, id]);
}
