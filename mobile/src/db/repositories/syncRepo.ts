import type { Note, UpdateNotePayload } from "@shared/notes";
import type { Folder } from "@shared/folders";
import type { Task, CreateTaskPayload, UpdateTaskPayload } from "@shared/tasks";
import { getLocalDatabase } from "@/db/client";
import { apiClient } from "@/api/apiClient";
import {
  replaceLocalNoteID,
  upsertNotesLocal,
} from "@/db/repositories/notesRepo";
import {
  replaceLocalFolderID,
  upsertFoldersLocal,
} from "@/db/repositories/foldersRepo";
import {
  replaceLocalTaskID,
  upsertTasksLocal,
} from "@/db/repositories/tasksRepo";

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
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

async function enqueueOp(entityType: SyncEntity, entityID: string, opType: SyncOpType, payload: OutboxPayload) {
  const db = await getLocalDatabase();

  const existing = await db.getFirstAsync<{ op_id: string; op_type: SyncOpType }>(
    `
      SELECT op_id, op_type
      FROM sync_outbox
      WHERE entity_type = ? AND entity_id = ?
      ORDER BY created_at DESC
      LIMIT 1
    `,
    entityType,
    entityID,
  );

  if (existing) {
    await db.runAsync(
      `
        UPDATE sync_outbox
        SET op_type = ?,
            payload_json = ?,
            retry_count = 0,
            next_retry_at = NULL,
            created_at = ?
        WHERE op_id = ?
      `,
      opType,
      JSON.stringify(payload),
      nowISO(),
      existing.op_id,
    );
    return existing.op_id;
  }

  const opID = generateID();
  await db.runAsync(
    `
      INSERT INTO sync_outbox (
        op_id, entity_type, entity_id, op_type, payload_json, created_at, retry_count, next_retry_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, NULL)
    `,
    opID,
    entityType,
    entityID,
    opType,
    JSON.stringify(payload),
    nowISO(),
  );

  return opID;
}

export async function enqueueNoteUpsert(noteID: string, payload: UpdateNotePayload & { title?: string; content?: string }) {
  return enqueueOp("note", noteID, "upsert", payload);
}

export async function enqueueNoteDelete(noteID: string) {
  return enqueueOp("note", noteID, "delete", {});
}

export async function enqueueFolderUpsert(folderID: string, payload: { name: string }) {
  return enqueueOp("folder", folderID, "upsert", payload);
}

export async function enqueueFolderDelete(folderID: string) {
  return enqueueOp("folder", folderID, "delete", {});
}

export async function enqueueTaskUpsert(taskID: string, payload: UpdateTaskPayload) {
  return enqueueOp("task", taskID, "upsert", payload);
}

export async function enqueueTaskDelete(taskID: string) {
  return enqueueOp("task", taskID, "delete", {});
}

async function listPendingOps(limit = 50) {
  const db = await getLocalDatabase();
  return db.getAllAsync<OutboxRow>(
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
    nowISO(),
    limit,
  );
}

async function deleteOp(opID: string) {
  const db = await getLocalDatabase();
  await db.runAsync(`DELETE FROM sync_outbox WHERE op_id = ?`, opID);
}

async function bumpRetry(opID: string, retryCount: number) {
  const db = await getLocalDatabase();
  const nextCount = retryCount + 1;
  const backoffSeconds = Math.min(60, Math.pow(2, nextCount));
  const nextRetryAt = new Date(Date.now() + backoffSeconds * 1000).toISOString();
  await db.runAsync(
    `
      UPDATE sync_outbox
      SET retry_count = ?, next_retry_at = ?
      WHERE op_id = ?
    `,
    nextCount,
    nextRetryAt,
    opID,
  );
}

async function clearDirtyFlag(entityType: SyncEntity, entityID: string) {
  const db = await getLocalDatabase();
  if (entityType === "note") {
    await db.runAsync(`UPDATE notes SET dirty = 0 WHERE id = ?`, entityID);
    return;
  }
  if (entityType === "task") {
    await db.runAsync(`UPDATE tasks SET dirty = 0 WHERE id = ?`, entityID);
    return;
  }

  await db.runAsync(`UPDATE folders SET dirty = 0 WHERE id = ?`, entityID);
}

async function processNoteUpsert(op: OutboxRow, payload: OutboxPayload) {
  const body = payload as UpdateNotePayload & { title?: string; content?: string };
  const hasServerSideRecord = !op.entity_id.startsWith("local_");

  if (hasServerSideRecord) {
    const updated = await apiClient.patch<Note, typeof body>(`/notes/${op.entity_id}`, body);
    await upsertNotesLocal([updated]);
    await clearDirtyFlag("note", updated.id);
    return;
  }

  const created = await apiClient.post<Note, typeof body>("/notes/", {
    title: typeof body.title === "string" ? body.title : "Untitled",
    content: typeof body.content === "string" ? body.content : "",
    ...(body.folderId ? { folderId: body.folderId } : {}),
    ...(body.isPinned !== undefined ? { isPinned: body.isPinned } : {}),
  });

  await replaceLocalNoteID(op.entity_id, created.id);
  await upsertNotesLocal([created]);
  await clearDirtyFlag("note", created.id);

  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE sync_outbox
      SET entity_id = ?
      WHERE entity_type = 'note' AND entity_id = ?
    `,
    created.id,
    op.entity_id,
  );
}

async function processFolderUpsert(op: OutboxRow, payload: OutboxPayload) {
  const body = payload as { name?: string };
  const hasServerSideRecord = !op.entity_id.startsWith("local_");

  if (hasServerSideRecord) {
    const updated = await apiClient.patch<Folder, { name: string }>(
      `/folders/${op.entity_id}`,
      { name: body.name ?? "Untitled Folder" },
    );
    await upsertFoldersLocal([updated]);
    await clearDirtyFlag("folder", updated.id);
    return;
  }

  const created = await apiClient.post<Folder, { name: string }>(
    "/folders/",
    { name: body.name ?? "Untitled Folder" },
  );

  await replaceLocalFolderID(op.entity_id, created.id);
  await upsertFoldersLocal([created]);
  await clearDirtyFlag("folder", created.id);

  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE sync_outbox
      SET entity_id = ?
      WHERE entity_type = 'folder' AND entity_id = ?
    `,
    created.id,
    op.entity_id,
  );
}

async function processNoteDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/notes/${op.entity_id}`);
  } catch {
    // Keep local deletion state even if remote already removed
  }
  const db = await getLocalDatabase();
  await db.runAsync(`DELETE FROM notes WHERE id = ?`, op.entity_id);
}

async function processFolderDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/folders/${op.entity_id}`);
  } catch {
    // Keep local deletion state even if remote already removed
  }
  const db = await getLocalDatabase();
  await db.runAsync(`DELETE FROM folders WHERE id = ?`, op.entity_id);
}

async function processTaskUpsert(op: OutboxRow, payload: OutboxPayload) {
  const body = payload as UpdateTaskPayload;
  const hasServerSideRecord = !op.entity_id.startsWith("local_");

  if (hasServerSideRecord) {
    const updated = await apiClient.patch<Task, typeof body>(`/tasks/${op.entity_id}`, body);
    await upsertTasksLocal([updated]);
    await clearDirtyFlag("task", updated.id);
    return;
  }

  const created = await apiClient.post<Task, CreateTaskPayload>("/tasks/", {
    title: body.title ?? "Untitled",
    description: body.description ?? "",
    isCompleted: body.isCompleted ?? false,
    dueDate: body.dueDate,
  });

  await replaceLocalTaskID(op.entity_id, created.id);
  await upsertTasksLocal([created]);
  await clearDirtyFlag("task", created.id);

  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE sync_outbox
      SET entity_id = ?
      WHERE entity_type = 'task' AND entity_id = ?
    `,
    created.id,
    op.entity_id,
  );
}

async function processTaskDelete(op: OutboxRow) {
  try {
    await apiClient.delete<void>(`/tasks/${op.entity_id}`);
  } catch {
    // Keep local deletion state even if remote already removed
  }
  const db = await getLocalDatabase();
  await db.runAsync(`DELETE FROM tasks WHERE id = ?`, op.entity_id);
}

export async function runSyncCycle() {
  const remoteFolders = await apiClient.get<Folder[]>("/folders/");
  const remoteNotes = await apiClient.get<Note[]>("/notes/");
  const remoteTasks = await apiClient.get<Task[]>("/tasks/");

  await upsertFoldersLocal(remoteFolders);
  await upsertNotesLocal(remoteNotes);
  await upsertTasksLocal(remoteTasks);

  const ops = await listPendingOps(100);
  for (const op of ops) {
    try {
      const payload = JSON.parse(op.payload_json || "{}") as OutboxPayload;

      if (op.entity_type === "note" && op.op_type === "upsert") {
        await processNoteUpsert(op, payload);
      } else if (op.entity_type === "note" && op.op_type === "delete") {
        await processNoteDelete(op);
      } else if (op.entity_type === "folder" && op.op_type === "upsert") {
        await processFolderUpsert(op, payload);
      } else if (op.entity_type === "folder" && op.op_type === "delete") {
        await processFolderDelete(op);
      } else if (op.entity_type === "task" && op.op_type === "upsert") {
        await processTaskUpsert(op, payload);
      } else if (op.entity_type === "task" && op.op_type === "delete") {
        await processTaskDelete(op);
      }

      await deleteOp(op.op_id);
    } catch {
      await bumpRetry(op.op_id, op.retry_count);
    }
  }
}
