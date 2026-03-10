import type { Folder } from "@shared/folders";
import type { Note, UpdateNotePayload } from "@shared/notes";
import { apiClient } from "@/services";
import { getLocalDatabase } from "@/db/client";
import { replaceLocalFolderID, upsertFoldersLocal } from "@/db/repositories/foldersRepo";
import { replaceLocalNoteID, upsertNotesLocal } from "@/db/repositories/notesRepo";
import { replaceLocalTaskID, upsertTasksLocal } from "@/db/repositories/tasksRepo";
import type { Task, UpdateTaskPayload } from "@shared/tasks";

type SyncEntity = "note" | "folder" | "task";
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
  await db.execute(
    `
      INSERT INTO sync_outbox (
        op_id, entity_type, entity_id, op_type, payload_json, created_at, retry_count, next_retry_at
      ) VALUES ($1, $2, $3, $4, $5, $6, 0, NULL)
    `,
    [opID, entityType, entityID, opType, JSON.stringify(payload), nowISO()],
  );
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

export async function enqueueTaskUpsert(taskID: string, payload: UpdateTaskPayload) {
  await enqueue("task", taskID, "upsert", payload as OutboxPayload);
}

export async function enqueueTaskDelete(taskID: string) {
  await enqueue("task", taskID, "delete", {});
}

async function listPendingOps(limit = 100): Promise<OutboxRow[]> {
  const db = await getLocalDatabase();
  const rows = await db.select<OutboxRow[]>(
    `
      SELECT op_id, entity_type, entity_id, op_type, payload_json, created_at, retry_count
      FROM sync_outbox
      WHERE next_retry_at IS NULL OR next_retry_at <= $1
      ORDER BY
        CASE entity_type WHEN 'folder' THEN 0 ELSE 1 END ASC,
        CASE op_type WHEN 'upsert' THEN 0 ELSE 1 END ASC,
        created_at ASC
      LIMIT $2
    `,
    [nowISO(), limit],
  );

  return rows;
}

async function removeOp(opID: string) {
  const db = await getLocalDatabase();
  await db.execute(`DELETE FROM sync_outbox WHERE op_id = $1`, [opID]);
}

async function bumpRetry(opID: string, retryCount: number) {
  const db = await getLocalDatabase();
  const nextCount = retryCount + 1;
  const nextRetryAt = new Date(Date.now() + Math.min(60, 2 ** nextCount) * 1000).toISOString();
  await db.execute(
    `UPDATE sync_outbox SET retry_count = $1, next_retry_at = $2 WHERE op_id = $3`,
    [nextCount, nextRetryAt, opID],
  );
}

async function markDirtyCleared(entity: SyncEntity, id: string) {
  const db = await getLocalDatabase();
  if (entity === "note") {
    await db.execute(`UPDATE notes SET dirty = 0 WHERE id = $1`, [id]);
  } else if (entity === "folder") {
    await db.execute(`UPDATE folders SET dirty = 0 WHERE id = $1`, [id]);
  } else {
    await db.execute(`UPDATE tasks SET dirty = 0 WHERE id = $1`, [id]);
  }
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

async function processTaskUpsert(op: OutboxRow, payload: UpdateTaskPayload) {
  const isLocal = op.entity_id.startsWith("local_");
  if (isLocal) {
    const created = await apiClient.post<Task, UpdateTaskPayload>("/tasks/", {
      title: payload.title ?? "Untitled",
      description: payload.description ?? "",
      isCompleted: payload.isCompleted ?? false,
      dueDate: payload.dueDate,
    });
    await replaceLocalTaskID(op.entity_id, created.id);
    await upsertTasksLocal([created]);
    await markDirtyCleared("task", created.id);
    return;
  }

  const updated = await apiClient.patch<Task, UpdateTaskPayload>(`/tasks/${op.entity_id}`, payload);
  await upsertTasksLocal([updated]);
  await markDirtyCleared("task", updated.id);
}

async function processTaskDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/tasks/${op.entity_id}`);
  } catch {
    // Keep local delete regardless
  }
}

export async function runSyncCycle() {
  const remoteFolders = await apiClient.get<Folder[]>("/folders/");
  const remoteNotes = await apiClient.get<Note[]>("/notes/");
  const remoteTasks = await apiClient.get<Task[]>("/tasks/");
  await upsertFoldersLocal(remoteFolders);
  await upsertNotesLocal(remoteNotes);
  await upsertTasksLocal(remoteTasks);

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
      } else if (op.entity_type === "task" && op.op_type === "upsert") {
        await processTaskUpsert(op, payload as UpdateTaskPayload);
      } else if (op.entity_type === "task" && op.op_type === "delete") {
        await processTaskDelete(op);
      }

      await removeOp(op.op_id);
    } catch {
      await bumpRetry(op.op_id, op.retry_count);
    }
  }
}
