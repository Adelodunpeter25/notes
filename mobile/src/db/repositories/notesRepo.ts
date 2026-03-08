import type { ListNotesParams, Note } from "@shared/notes";
import { getLocalDatabase } from "@/db/client";

type NoteRow = {
  id: string;
  folder_id: string | null;
  title: string;
  content: string;
  is_pinned: number;
  created_at: string | null;
  updated_at: string | null;
};

function mapRow(row: NoteRow): Note {
  return {
    id: row.id,
    folderId: row.folder_id ?? undefined,
    title: row.title,
    content: row.content,
    isPinned: Boolean(row.is_pinned),
    createdAt: row.created_at ?? undefined,
    updatedAt: row.updated_at ?? undefined,
  };
}

export async function listNotesLocal(params?: ListNotesParams): Promise<Note[]> {
  const db = await getLocalDatabase();

  const q = params?.q?.trim() || null;
  const search = q ? `%${q}%` : null;

  const rows = await db.getAllAsync<NoteRow>(
    `
      SELECT
        id,
        folder_id,
        title,
        content,
        is_pinned,
        created_at,
        updated_at
      FROM notes
      WHERE deleted_at IS NULL
        AND (? IS NULL OR folder_id = ?)
        AND (? IS NULL OR title LIKE ? OR content LIKE ?)
      ORDER BY is_pinned DESC, COALESCE(updated_at, created_at) DESC
    `,
    params?.folderId ?? null,
    params?.folderId ?? null,
    q,
    search,
    search,
  );

  return rows.map(mapRow);
}

export async function upsertNotesLocal(notes: Note[]): Promise<void> {
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

