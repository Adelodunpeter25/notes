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
  const now = new Date().toISOString();

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

