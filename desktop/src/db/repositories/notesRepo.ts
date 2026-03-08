import type { ListNotesParams, Note, UpdateNotePayload } from "@shared/notes";
import { getLocalDatabase, persistDatabase } from "@/db/client";

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

  const statement = db.prepare(`
    SELECT id, folder_id, title, content, is_pinned, created_at, updated_at
    FROM notes
    WHERE deleted_at IS NULL
      AND (? IS NULL OR folder_id = ?)
      AND (? = '' OR lower(title) LIKE lower(?) OR lower(content) LIKE lower(?))
    ORDER BY is_pinned DESC, COALESCE(updated_at, created_at) DESC
  `);

  const likePattern = `%${query}%`;
  statement.bind([folderID, folderID, query, likePattern, likePattern]);

  const rows: NoteRow[] = [];
  while (statement.step()) {
    rows.push(statement.getAsObject() as unknown as NoteRow);
  }
  statement.free();

  return rows.map(mapRow);
}

export async function upsertNotesLocal(notes: Note[]): Promise<void> {
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

  db.run(
    `
      INSERT INTO notes (
        id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at, dirty
      ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1)
    `,
    [note.id, note.folderId ?? null, note.title, note.content, note.isPinned ? 1 : 0, note.createdAt, note.updatedAt],
  );

  await persistDatabase();
  return note;
}

export async function updateNoteLocal(noteId: string, payload: UpdateNotePayload): Promise<Note | null> {
  const db = await getLocalDatabase();
  const result = db.exec(
    `
      SELECT id, folder_id, title, content, is_pinned, created_at, updated_at
      FROM notes
      WHERE id = ? AND deleted_at IS NULL
    `,
    [noteId],
  );

  if (!result.length || !result[0].values.length) {
    return null;
  }

  const row = result[0].values[0];
  const current: Note = {
    id: String(row[0]),
    folderId: row[1] ? String(row[1]) : undefined,
    title: String(row[2]),
    content: String(row[3]),
    isPinned: Number(row[4]) === 1,
    createdAt: row[5] ? String(row[5]) : undefined,
    updatedAt: row[6] ? String(row[6]) : undefined,
  };

  const updated: Note = {
    ...current,
    ...(payload.folderId !== undefined ? { folderId: payload.folderId } : {}),
    ...(payload.title !== undefined ? { title: payload.title } : {}),
    ...(payload.content !== undefined ? { content: payload.content } : {}),
    ...(payload.isPinned !== undefined ? { isPinned: payload.isPinned } : {}),
    updatedAt: nowISO(),
  };

  db.run(
    `
      UPDATE notes
      SET folder_id = ?,
          title = ?,
          content = ?,
          is_pinned = ?,
          updated_at = ?,
          dirty = 1
      WHERE id = ?
    `,
    [updated.folderId ?? null, updated.title, updated.content, updated.isPinned ? 1 : 0, updated.updatedAt ?? null, noteId],
  );

  await persistDatabase();
  return updated;
}

export async function markNoteDeletedLocal(noteId: string) {
  const db = await getLocalDatabase();
  const now = nowISO();
  db.run(
    `UPDATE notes SET deleted_at = ?, updated_at = ?, dirty = 1 WHERE id = ?`,
    [now, now, noteId],
  );
  await persistDatabase();
}

export async function replaceLocalNoteID(oldID: string, newID: string) {
  const db = await getLocalDatabase();
  db.run(`UPDATE notes SET id = ? WHERE id = ?`, [newID, oldID]);
  db.run(`UPDATE sync_outbox SET entity_id = ? WHERE entity_type = 'note' AND entity_id = ?`, [newID, oldID]);
  await persistDatabase();
}
