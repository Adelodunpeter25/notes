import type { ListNotesParams, Note, UpdateNotePayload } from "@shared/notes";
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

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `local_${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function listNotesLocal(params?: ListNotesParams): Promise<Note[]> {
  const db = await getLocalDatabase();
  const folderID = params?.folderId ?? null;
  const query = params?.q?.trim() ?? "";
  const likePattern = `%${query}%`;

  const rows = await db.select<NoteRow[]>(
    `
    SELECT id, folder_id, title, content, is_pinned, created_at, updated_at
    FROM notes
    WHERE deleted_at IS NULL
      AND ($1 IS NULL OR folder_id = $2)
      AND ($3 = '' OR lower(title) LIKE lower($4) OR lower(content) LIKE lower($5))
    ORDER BY is_pinned DESC, COALESCE(updated_at, created_at) DESC
  `,
    [folderID, folderID, query, likePattern, likePattern],
  );

  return rows.map(mapRow);
}

export async function upsertNotesLocal(notes: Note[]): Promise<void> {
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

export async function createNoteLocal(payload: {
  folderId?: string;
  title?: string;
  content?: string;
  isPinned?: boolean;
}) {
  const db = await getLocalDatabase();
  const id = generateID();
  const timestamp = nowISO();

  const note: Note = {
    id,
    folderId: payload.folderId,
    title: payload.title ?? "Untitled",
    content: payload.content ?? "",
    isPinned: payload.isPinned ?? false,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await db.execute(
    `
      INSERT INTO notes (
        id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at, dirty
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 1)
    `,
    [note.id, note.folderId ?? null, note.title, note.content, note.isPinned ? 1 : 0, note.createdAt, note.updatedAt],
  );

  return note;
}

export async function updateNoteLocal(noteId: string, payload: UpdateNotePayload): Promise<Note | null> {
  const db = await getLocalDatabase();
  const rows = await db.select<NoteRow[]>(
    `
      SELECT id, folder_id, title, content, is_pinned, created_at, updated_at
      FROM notes
      WHERE id = $1 AND deleted_at IS NULL
    `,
    [noteId],
  );

  if (!rows.length) {
    return null;
  }

  const row = rows[0];
  const current: Note = mapRow(row);

  const updated: Note = {
    ...current,
    ...(payload.folderId !== undefined ? { folderId: payload.folderId } : {}),
    ...(payload.title !== undefined ? { title: payload.title } : {}),
    ...(payload.content !== undefined ? { content: payload.content } : {}),
    ...(payload.isPinned !== undefined ? { isPinned: payload.isPinned } : {}),
    updatedAt: nowISO(),
  };

  await db.execute(
    `
      UPDATE notes
      SET folder_id = $1,
          title = $2,
          content = $3,
          is_pinned = $4,
          updated_at = $5,
          dirty = 1
      WHERE id = $6
    `,
    [updated.folderId ?? null, updated.title, updated.content, updated.isPinned ? 1 : 0, updated.updatedAt ?? null, noteId],
  );

  return updated;
}

export async function markNoteDeletedLocal(noteId: string) {
  const db = await getLocalDatabase();
  const now = nowISO();
  await db.execute(
    `UPDATE notes SET deleted_at = $1, updated_at = $2, dirty = 1 WHERE id = $3`,
    [now, now, noteId],
  );
}

export async function replaceLocalNoteID(oldID: string, newID: string) {
  const db = await getLocalDatabase();
  await db.execute(`UPDATE notes SET id = $1 WHERE id = $2`, [newID, oldID]);
  await db.execute(`UPDATE sync_outbox SET entity_id = $1 WHERE entity_type = 'note' AND entity_id = $2`, [newID, oldID]);
}
