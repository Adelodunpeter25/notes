import type { Folder } from "@shared/folders";
import type { Note } from "@shared/notes";
import { getLocalDatabase, persistDatabase } from "@/db/client";

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `local_${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function listFoldersLocal(): Promise<Folder[]> {
  const db = await getLocalDatabase();
  const result = db.exec(`
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

  if (!result.length) {
    return [];
  }

  return result[0].values.map((row: unknown[]) => ({
    id: String(row[0]),
    name: String(row[1]),
    notesCount: Number(row[2]) || 0,
  }));
}

export async function upsertFoldersLocal(folders: Folder[]): Promise<void> {
  if (!folders.length) return;

  const db = await getLocalDatabase();
  const statement = db.prepare(`
    INSERT INTO folders (
      id, name, created_at, updated_at, deleted_at, dirty
    )
    VALUES (?, ?, ?, ?, NULL, 0)
    ON CONFLICT(id) DO UPDATE SET
      name = excluded.name,
      updated_at = excluded.updated_at,
      deleted_at = NULL
    WHERE folders.dirty = 0
  `);

  const now = nowISO();
  for (const folder of folders) {
    statement.run([folder.id, folder.name, now, now]);
  }
  statement.free();
  await persistDatabase();
}

export async function upsertFolderNotesLocal(notes: Note[]): Promise<void> {
  if (!notes.length) return;
  const db = await getLocalDatabase();
  const statement = db.prepare(`
    INSERT INTO notes (
      id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at, dirty
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 0)
    ON CONFLICT(id) DO UPDATE SET
      folder_id = excluded.folder_id,
      title = excluded.title,
      content = excluded.content,
      is_pinned = excluded.is_pinned,
      created_at = excluded.created_at,
      updated_at = excluded.updated_at,
      deleted_at = NULL
    WHERE notes.dirty = 0
  `);

  for (const note of notes) {
    statement.run([
      note.id,
      note.folderId ?? null,
      note.title ?? "Untitled",
      note.content ?? "",
      note.isPinned ? 1 : 0,
      note.createdAt ?? null,
      note.updatedAt ?? null,
    ]);
  }
  statement.free();
  await persistDatabase();
}

export async function createFolderLocal(name: string): Promise<Folder> {
  const db = await getLocalDatabase();
  const id = generateID();
  const now = nowISO();
  db.run(
    `INSERT INTO folders (id, name, created_at, updated_at, deleted_at, dirty) VALUES (?, ?, ?, ?, NULL, 1)`,
    [id, name, now, now],
  );
  await persistDatabase();
  return { id, name, notesCount: 0 };
}

export async function renameFolderLocal(folderId: string, name: string): Promise<Folder | null> {
  const db = await getLocalDatabase();
  db.run(
    `UPDATE folders SET name = ?, updated_at = ?, dirty = 1 WHERE id = ? AND deleted_at IS NULL`,
    [name, nowISO(), folderId],
  );
  await persistDatabase();

  const result = db.exec(`SELECT id, name FROM folders WHERE id = ? AND deleted_at IS NULL`, [folderId]);
  if (!result.length || !result[0].values.length) {
    return null;
  }

  const row = result[0].values[0];
  return { id: String(row[0]), name: String(row[1]), notesCount: 0 };
}

export async function markFolderDeletedLocal(folderId: string) {
  const db = await getLocalDatabase();
  const now = nowISO();
  db.run(`UPDATE folders SET deleted_at = ?, updated_at = ?, dirty = 1 WHERE id = ?`, [now, now, folderId]);
  await persistDatabase();
}

export async function replaceLocalFolderID(oldID: string, newID: string) {
  const db = await getLocalDatabase();
  db.run(`UPDATE folders SET id = ? WHERE id = ?`, [newID, oldID]);
  db.run(`UPDATE notes SET folder_id = ? WHERE folder_id = ?`, [newID, oldID]);
  db.run(`UPDATE sync_outbox SET entity_id = ? WHERE entity_type = 'folder' AND entity_id = ?`, [newID, oldID]);
  await persistDatabase();
}
