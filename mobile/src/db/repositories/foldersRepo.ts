import type { Folder } from "@shared/folders";
import type { Note } from "@shared/notes";
import { getLocalDatabase } from "@/db/client";

type FolderRow = {
  id: string;
  name: string;
  notes_count: number;
};

function mapFolderRow(row: FolderRow): Folder {
  return {
    id: row.id,
    name: row.name,
    notesCount: row.notes_count,
  };
}

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  const uniquePart =
    typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

  return `local_${uniquePart}`;
}

export async function listFoldersLocal(): Promise<Folder[]> {
  const db = await getLocalDatabase();

  const rows = await db.getAllAsync<FolderRow>(
    `
      SELECT
        f.id,
        f.name,
        COUNT(n.id) AS notes_count
      FROM folders f
      LEFT JOIN notes n ON n.folder_id = f.id AND n.deleted_at IS NULL
      WHERE f.deleted_at IS NULL
      GROUP BY f.id, f.name
      ORDER BY f.name COLLATE NOCASE ASC
    `,
  );

  return rows.map(mapFolderRow);
}

export async function upsertFoldersLocal(folders: Folder[]): Promise<void> {
  if (!folders.length) {
    return;
  }

  const db = await getLocalDatabase();
  const now = nowISO();

  for (const folder of folders) {
    await db.runAsync(
      `
        INSERT INTO folders (
          id,
          name,
          created_at,
          updated_at,
          deleted_at,
          dirty
        )
        VALUES (?, ?, ?, ?, NULL, 0)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          updated_at = excluded.updated_at,
          deleted_at = NULL
        WHERE folders.dirty = 0
      `,
      folder.id,
      folder.name,
      now,
      now,
    );
  }
}

export async function upsertFolderNotesLocal(notes: Note[]): Promise<void> {
  if (!notes.length) {
    return;
  }

  const db = await getLocalDatabase();

  for (const note of notes) {
    await db.runAsync(
      `
        INSERT INTO notes (
          id,
          folder_id,
          title,
          content,
          is_pinned,
          created_at,
          updated_at,
          deleted_at,
          dirty
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
      `,
      note.id,
      note.folderId ?? null,
      note.title ?? "Untitled",
      note.content ?? "",
      note.isPinned ? 1 : 0,
      note.createdAt ?? null,
      note.updatedAt ?? null,
    );
  }
}

export async function getFolderByIDLocal(folderId: string): Promise<Folder | null> {
  const db = await getLocalDatabase();
  const row = await db.getFirstAsync<{ id: string; name: string }>(
    `SELECT id, name FROM folders WHERE id = ? AND deleted_at IS NULL`,
    folderId,
  );
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    name: row.name,
    notesCount: 0,
  };
}

export async function createFolderLocal(name: string): Promise<Folder> {
  const db = await getLocalDatabase();
  const id = generateID();
  const now = nowISO();
  await db.runAsync(
    `
      INSERT INTO folders (id, name, created_at, updated_at, deleted_at, dirty)
      VALUES (?, ?, ?, ?, NULL, 1)
    `,
    id,
    name,
    now,
    now,
  );

  return { id, name, notesCount: 0 };
}

export async function renameFolderLocal(folderId: string, name: string): Promise<Folder | null> {
  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE folders
      SET name = ?, updated_at = ?, dirty = 1
      WHERE id = ? AND deleted_at IS NULL
    `,
    name,
    nowISO(),
    folderId,
  );

  return getFolderByIDLocal(folderId);
}

export async function markFolderDeletedLocal(folderId: string): Promise<void> {
  const db = await getLocalDatabase();
  const now = nowISO();
  await db.runAsync(
    `
      UPDATE folders
      SET deleted_at = ?, updated_at = ?, dirty = 1
      WHERE id = ?
    `,
    now,
    now,
    folderId,
  );
}

export async function replaceLocalFolderID(oldID: string, newID: string): Promise<void> {
  const db = await getLocalDatabase();
  await db.runAsync(`UPDATE folders SET id = ? WHERE id = ?`, newID, oldID);
  await db.runAsync(`UPDATE notes SET folder_id = ? WHERE folder_id = ?`, newID, oldID);
}
