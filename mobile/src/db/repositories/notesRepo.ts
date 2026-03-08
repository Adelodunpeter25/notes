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

function buildFtsMatchQuery(input: string | null | undefined): string | null {
  const trimmed = input?.trim();
  if (!trimmed) {
    return null;
  }

  const tokens = trimmed
    .split(/\s+/)
    .map((token) => token.replace(/"/g, '""').trim())
    .filter(Boolean);

  if (!tokens.length) {
    return null;
  }

  return tokens.map((token) => `"${token}"*`).join(" AND ");
}

export async function listNotesLocal(params?: ListNotesParams): Promise<Note[]> {
  const db = await getLocalDatabase();

  const q = params?.q?.trim() || null;
  const folderID = params?.folderId ?? null;
  const ftsQuery = buildFtsMatchQuery(q);

  const rows = ftsQuery
    ? await db.getAllAsync<NoteRow>(
      `
        SELECT
          n.id,
          n.folder_id,
          n.title,
          n.content,
          n.is_pinned,
          n.created_at,
          n.updated_at
        FROM notes n
        JOIN notes_fts ON notes_fts.rowid = n.rowid
        WHERE n.deleted_at IS NULL
          AND (? IS NULL OR n.folder_id = ?)
          AND notes_fts MATCH ?
        ORDER BY
          n.is_pinned DESC,
          bm25(notes_fts),
          COALESCE(n.updated_at, n.created_at) DESC
      `,
      folderID,
      folderID,
      ftsQuery,
    )
    : await db.getAllAsync<NoteRow>(
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
        ORDER BY is_pinned DESC, COALESCE(updated_at, created_at) DESC
      `,
      folderID,
      folderID,
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

export async function getNoteByIDLocal(noteId: string): Promise<Note | null> {
  const db = await getLocalDatabase();
  const row = await db.getFirstAsync<NoteRow>(
    `
      SELECT id, folder_id, title, content, is_pinned, created_at, updated_at
      FROM notes
      WHERE id = ? AND deleted_at IS NULL
    `,
    noteId,
  );

  return row ? mapRow(row) : null;
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

  await db.runAsync(
    `
      INSERT INTO notes (
        id, folder_id, title, content, is_pinned, created_at, updated_at, deleted_at, dirty
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1)
    `,
    note.id,
    note.folderId ?? null,
    note.title,
    note.content,
    note.isPinned ? 1 : 0,
    note.createdAt ?? null,
    note.updatedAt ?? null,
  );

  return note;
}

export async function updateNoteLocal(noteId: string, payload: {
  folderId?: string;
  title?: string;
  content?: string;
  isPinned?: boolean;
}): Promise<Note | null> {
  const existing = await getNoteByIDLocal(noteId);
  if (!existing) {
    return null;
  }

  const db = await getLocalDatabase();
  const updated: Note = {
    ...existing,
    ...(payload.folderId !== undefined ? { folderId: payload.folderId } : {}),
    ...(payload.title !== undefined ? { title: payload.title } : {}),
    ...(payload.content !== undefined ? { content: payload.content } : {}),
    ...(payload.isPinned !== undefined ? { isPinned: payload.isPinned } : {}),
    updatedAt: nowISO(),
  };

  await db.runAsync(
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
    updated.folderId ?? null,
    updated.title,
    updated.content,
    updated.isPinned ? 1 : 0,
    updated.updatedAt ?? null,
    noteId,
  );

  return updated;
}

export async function markNoteDeletedLocal(noteId: string): Promise<void> {
  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE notes
      SET deleted_at = ?, updated_at = ?, dirty = 1
      WHERE id = ?
    `,
    nowISO(),
    nowISO(),
    noteId,
  );
}

export async function replaceLocalNoteID(oldID: string, newID: string): Promise<void> {
  const db = await getLocalDatabase();
  await db.runAsync(`UPDATE notes SET id = ? WHERE id = ?`, newID, oldID);
}
