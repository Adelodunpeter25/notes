import type { Folder } from "@shared/folders";
import type { Note, UpdateNotePayload } from "@shared/notes";
import { apiClient } from "@/services";
import { getLocalDatabase, persistDatabase } from "@/db/client";
import { replaceLocalFolderID, upsertFoldersLocal } from "@/db/repositories/foldersRepo";
import { replaceLocalNoteID, upsertNotesLocal } from "@/db/repositories/notesRepo";

type SyncEntity = "note" | "folder";
type SyncOpType = "upsert" | "delete";

type OutboxRow = {
  op_id: string;
  entity_type: SyncEntity;
  entity_id: string;
  op_type: SyncOpType;
  payload_json: string;
  created_at: string;
  retry_count: number;
};

type OutboxPayload = Record<string, unknown>;

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `op_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

async function enqueue(entityType: SyncEntity, entityID: string, opType: SyncOpType, payload: OutboxPayload) {
  const db = await getLocalDatabase();
  const opID = generateID();
  db.run(
    `
      INSERT INTO sync_outbox (
        op_id, entity_type, entity_id, op_type, payload_json, created_at, retry_count, next_retry_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, NULL)
    `,
    [opID, entityType, entityID, opType, JSON.stringify(payload), nowISO()],
  );
  await persistDatabase();
}

export async function enqueueNoteUpsert(noteID: string, payload: UpdateNotePayload) {
  await enqueue("note", noteID, "upsert", payload as OutboxPayload);
}

export async function enqueueNoteDelete(noteID: string) {
  await enqueue("note", noteID, "delete", {});
}

export async function enqueueFolderUpsert(folderID: string, payload: { name: string }) {
  await enqueue("folder", folderID, "upsert", payload as OutboxPayload);
}

export async function enqueueFolderDelete(folderID: string) {
  await enqueue("folder", folderID, "delete", {});
}

async function listPendingOps(limit = 100): Promise<OutboxRow[]> {
  const db = await getLocalDatabase();
  const result = db.exec(
    `
      SELECT op_id, entity_type, entity_id, op_type, payload_json, created_at, retry_count
      FROM sync_outbox
      WHERE next_retry_at IS NULL OR next_retry_at <= ?
      ORDER BY
        CASE entity_type WHEN 'folder' THEN 0 ELSE 1 END ASC,
        CASE op_type WHEN 'upsert' THEN 0 ELSE 1 END ASC,
        created_at ASC
      LIMIT ?
    `,
    [nowISO(), limit],
  );

  if (!result.length) {
    return [];
  }

  return result[0].values.map((row: unknown[]) => ({
    op_id: String(row[0]),
    entity_type: String(row[1]) as SyncEntity,
    entity_id: String(row[2]),
    op_type: String(row[3]) as SyncOpType,
    payload_json: String(row[4]),
    created_at: String(row[5]),
    retry_count: Number(row[6]) || 0,
  }));
}

async function removeOp(opID: string) {
  const db = await getLocalDatabase();
  db.run(`DELETE FROM sync_outbox WHERE op_id = ?`, [opID]);
  await persistDatabase();
}

async function bumpRetry(opID: string, retryCount: number) {
  const db = await getLocalDatabase();
  const nextCount = retryCount + 1;
  const nextRetryAt = new Date(Date.now() + Math.min(60, 2 ** nextCount) * 1000).toISOString();
  db.run(
    `UPDATE sync_outbox SET retry_count = ?, next_retry_at = ? WHERE op_id = ?`,
    [nextCount, nextRetryAt, opID],
  );
  await persistDatabase();
}

async function markDirtyCleared(entity: SyncEntity, id: string) {
  const db = await getLocalDatabase();
  if (entity === "note") {
    db.run(`UPDATE notes SET dirty = 0 WHERE id = ?`, [id]);
  } else {
    db.run(`UPDATE folders SET dirty = 0 WHERE id = ?`, [id]);
  }
  await persistDatabase();
}

async function processFolderUpsert(op: OutboxRow, payload: { name?: string }) {
  const isLocal = op.entity_id.startsWith("local_");
  if (isLocal) {
    const created = await apiClient.post<Folder, { name: string }>("/folders/", { name: payload.name ?? "Untitled Folder" });
    await replaceLocalFolderID(op.entity_id, created.id);
    await upsertFoldersLocal([created]);
    await markDirtyCleared("folder", created.id);
    return;
  }

  const updated = await apiClient.patch<Folder, { name: string }>(`/folders/${op.entity_id}`, { name: payload.name ?? "Untitled Folder" });
  await upsertFoldersLocal([updated]);
  await markDirtyCleared("folder", updated.id);
}

async function processNoteUpsert(op: OutboxRow, payload: UpdateNotePayload) {
  const isLocal = op.entity_id.startsWith("local_");
  if (isLocal) {
    const created = await apiClient.post<Note, {
      title: string;
      content: string;
      folderId?: string;
      isPinned?: boolean;
    }>("/notes/", {
      title: typeof payload.title === "string" ? payload.title : "Untitled",
      content: typeof payload.content === "string" ? payload.content : "",
      ...(payload.folderId ? { folderId: payload.folderId } : {}),
      ...(payload.isPinned !== undefined ? { isPinned: payload.isPinned } : {}),
    });
    await replaceLocalNoteID(op.entity_id, created.id);
    await upsertNotesLocal([created]);
    await markDirtyCleared("note", created.id);
    return;
  }

  const updated = await apiClient.patch<Note, UpdateNotePayload>(`/notes/${op.entity_id}`, payload);
  await upsertNotesLocal([updated]);
  await markDirtyCleared("note", updated.id);
}

async function processFolderDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/folders/${op.entity_id}`);
  } catch {
    // Keep local delete regardless
  }
}

async function processNoteDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/notes/${op.entity_id}`);
  } catch {
    // Keep local delete regardless
  }
}

export async function runSyncCycle() {
  const remoteFolders = await apiClient.get<Folder[]>("/folders/");
  const remoteNotes = await apiClient.get<Note[]>("/notes/");
  await upsertFoldersLocal(remoteFolders);
  await upsertNotesLocal(remoteNotes);

  const ops = await listPendingOps();
  for (const op of ops) {
    try {
      const payload = JSON.parse(op.payload_json || "{}") as OutboxPayload;

      if (op.entity_type === "folder" && op.op_type === "upsert") {
        await processFolderUpsert(op, payload as { name?: string });
      } else if (op.entity_type === "folder" && op.op_type === "delete") {
        await processFolderDelete(op);
      } else if (op.entity_type === "note" && op.op_type === "upsert") {
        await processNoteUpsert(op, payload as UpdateNotePayload);
      } else if (op.entity_type === "note" && op.op_type === "delete") {
        await processNoteDelete(op);
      }

      await removeOp(op.op_id);
    } catch {
      await bumpRetry(op.op_id, op.retry_count);
    }
  }
}
