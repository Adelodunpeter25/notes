import type { Folder } from "@shared/folders";
import type { Note } from "@shared/notes";
import { getLocalDatabase } from "@/db/client";

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `local_${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function listFoldersLocal(): Promise<Folder[]> {
  const db = await getLocalDatabase();
  const rows = await db.select<Array<{ id: string; name: string; notes_count: number }>>(`
    SELECT
      f.id,
      f.name,
      COUNT(n.id) AS notes_count
    FROM folders f
    LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
    WHERE f.deleted_at IS NULL
    GROUP BY f.id, f.name
    ORDER BY lower(f.name) ASC
  `);

  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    notesCount: row.notes_count || 0,
  }));
}

export async function upsertFoldersLocal(folders: Folder[]): Promise<void> {
  if (!folders.length) return;

  const db = await getLocalDatabase();
  const now = nowISO();

  for (const folder of folders) {
    await db.execute(
      `
      INSERT INTO folders (
        id, name, created_at, updated_at, deleted_at, dirty
      )
      VALUES ($1, $2, $3, $4, NULL, 0)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        updated_at = excluded.updated_at,
        deleted_at = NULL
      WHERE folders.dirty = 0
    `,
      [folder.id, folder.name, now, now],
    );
  }
}

export async function upsertFolderNotesLocal(notes: Note[]): Promise<void> {
  if (!notes.length) return;
  const db = await getLocalDatabase();

  for (const note of notes) {
    await db.execute(
      `
      INSERT INTO notes (
        id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at, dirty
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 0)
      ON CONFLICT(id) DO UPDATE SET
        folder_id = excluded.folder_id,
        title = excluded.title,
        content = excluded.content,
        is_pinned = excluded.is_pinned,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        deleted_at = NULL
      WHERE notes.dirty = 0
    `,
      [
        note.id,
        note.folderId ?? null,
        note.title ?? "Untitled",
        note.content ?? "",
        note.isPinned ? 1 : 0,
        note.createdAt ?? null,
        note.updatedAt ?? null,
      ],
    );
  }
}

export async function createFolderLocal(name: string): Promise<Folder> {
  const db = await getLocalDatabase();
  const id = generateID();
  const now = nowISO();
  await db.execute(
    `INSERT INTO folders (id, name, created_at, updated_at, deleted_at, dirty) VALUES ($1, $2, $3, $4, NULL, 1)`,
    [id, name, now, now],
  );
  return { id, name, notesCount: 0 };
}

export async function renameFolderLocal(folderId: string, name: string): Promise<Folder | null> {
  const db = await getLocalDatabase();
  await db.execute(
    `UPDATE folders SET name = $1, updated_at = $2, dirty = 1 WHERE id = $3 AND deleted_at IS NULL`,
    [name, nowISO(), folderId],
  );

  const rows = await db.select<Array<{ id: string; name: string }>>(
    `SELECT id, name FROM folders WHERE id = $1 AND deleted_at IS NULL`,
    [folderId],
  );

  if (!rows.length) {
    return null;
  }

  const row = rows[0];
  return { id: row.id, name: row.name, notesCount: 0 };
}

export async function markFolderDeletedLocal(folderId: string) {
  const db = await getLocalDatabase();
  const now = nowISO();
  await db.execute(`UPDATE folders SET deleted_at = $1, updated_at = $2, dirty = 1 WHERE id = $3`, [now, now, folderId]);
}

export async function replaceLocalFolderID(oldID: string, newID: string) {
  const db = await getLocalDatabase();
  await db.execute(`UPDATE folders SET id = $1 WHERE id = $2`, [newID, oldID]);
  await db.execute(`UPDATE notes SET folder_id = $1 WHERE folder_id = $2`, [newID, oldID]);
  await db.execute(`UPDATE sync_outbox SET entity_id = $1 WHERE entity_type = 'folder' AND entity_id = $2`, [newID, oldID]);
}
