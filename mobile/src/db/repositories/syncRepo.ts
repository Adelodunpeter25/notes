import type { UpdateNotePayload } from "@shared/notes";
import type { UpdateTaskPayload } from "@shared/tasks";
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
import type { SyncRequest, SyncResponse } from "@shared/sync";

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

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

const LAST_SYNC_KEY = "lastSyncCursor";

async function getStoredLastSyncCursor(): Promise<string | null> {
  const db = await getLocalDatabase();
  try {
    const row = await db.getFirstAsync<{ value: string | null }>(
      `SELECT value FROM sync_state_kv WHERE key = ? LIMIT 1`,
      LAST_SYNC_KEY,
    );
    return row?.value ?? null;
  } catch {
    return null;
  }
}

async function setStoredLastSyncCursor(value: string) {
  const db = await getLocalDatabase();
  await db.runAsync(
    `
      INSERT INTO sync_state_kv (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    `,
    LAST_SYNC_KEY,
    value,
  );
}

async function enqueueOp(entityType: SyncEntity, entityID: string, opType: SyncOpType, payload: Record<string, any>) {
  const db = await getLocalDatabase();

  if (opType === "upsert") {
      const existing = await db.getFirstAsync<OutboxRow>(
        `SELECT op_id, payload_json FROM sync_outbox WHERE entity_type = ? AND entity_id = ? AND op_type = 'upsert' LIMIT 1`,
        entityType,
        entityID,
      );

      if (existing) {
        const existingPayload = JSON.parse(existing.payload_json || "{}");
        const mergedPayload = { ...existingPayload, ...payload };
        await db.runAsync(
          `UPDATE sync_outbox SET payload_json = ?, created_at = ?, retry_count = 0, next_retry_at = NULL WHERE op_id = ?`,
          JSON.stringify(mergedPayload),
          nowISO(),
          existing.op_id,
        );
        return existing.op_id;
      }
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

export async function enqueueNoteUpsert(noteID: string, payload: UpdateNotePayload) {
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
  return enqueueOp("task", taskID, "upsert", normalizeTaskPayload(payload));
}

export async function enqueueTaskDelete(taskID: string) {
  return enqueueOp("task", taskID, "delete", {});
}

function normalizeTaskPayload(payload: UpdateTaskPayload): UpdateTaskPayload {
  const normalized: UpdateTaskPayload & { title?: unknown } = { ...payload };

  if (normalized.title && typeof normalized.title === "object") {
    const candidate = normalized.title as {
      title?: string;
      description?: string;
      isCompleted?: boolean;
      dueDate?: string;
    };

    if (typeof candidate.title === "string") {
      normalized.title = candidate.title;
      if (normalized.description === undefined && typeof candidate.description === "string") {
        normalized.description = candidate.description;
      }
      if (normalized.isCompleted === undefined && typeof candidate.isCompleted === "boolean") {
        normalized.isCompleted = candidate.isCompleted;
      }
      if (normalized.dueDate === undefined && typeof candidate.dueDate === "string") {
        normalized.dueDate = candidate.dueDate;
      }
    } else {
      delete normalized.title;
    }
  }

  return normalized;
}

async function listPendingOps(limit = 100) {
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

async function ensureOutboxForDirtyEntities() {
  const db = await getLocalDatabase();

  const dirtyNotes = await db.getAllAsync<{
    id: string;
    folder_id: string | null;
    title: string;
    content: string;
    is_pinned: number;
    deleted_at: string | null;
  }>(
    `
      SELECT id, folder_id, title, content, is_pinned, deleted_at
      FROM notes
      WHERE dirty = 1
    `,
  );

  for (const note of dirtyNotes) {
    await db.runAsync(
      `DELETE FROM sync_outbox WHERE entity_type = 'note' AND entity_id = ?`,
      note.id,
    );

    if (note.deleted_at) {
      await enqueueOp("note", note.id, "delete", {});
    } else {
      await enqueueOp("note", note.id, "upsert", {
        title: note.title,
        content: note.content,
        isPinned: Boolean(note.is_pinned),
        ...(note.folder_id ? { folderId: note.folder_id } : {}),
      });
    }
  }

  const dirtyFolders = await db.getAllAsync<{
    id: string;
    name: string;
    deleted_at: string | null;
  }>(
    `
      SELECT id, name, deleted_at
      FROM folders
      WHERE dirty = 1
    `,
  );

  for (const folder of dirtyFolders) {
    await db.runAsync(
      `DELETE FROM sync_outbox WHERE entity_type = 'folder' AND entity_id = ?`,
      folder.id,
    );

    if (folder.deleted_at) {
      await enqueueOp("folder", folder.id, "delete", {});
    } else {
      await enqueueOp("folder", folder.id, "upsert", { name: folder.name });
    }
  }

  const dirtyTasks = await db.getAllAsync<{
    id: string;
    title: string;
    description: string;
    is_completed: number;
    due_date: string | null;
    deleted_at: string | null;
  }>(
    `
      SELECT id, title, description, is_completed, due_date, deleted_at
      FROM tasks
      WHERE dirty = 1
    `,
  );

  for (const task of dirtyTasks) {
    await db.runAsync(
      `DELETE FROM sync_outbox WHERE entity_type = 'task' AND entity_id = ?`,
      task.id,
    );

    if (task.deleted_at) {
      await enqueueOp("task", task.id, "delete", {});
    } else {
      await enqueueOp("task", task.id, "upsert", {
        title: task.title,
        description: task.description,
        isCompleted: Boolean(task.is_completed),
        dueDate: task.due_date ?? undefined,
      });
    }
  }
}

async function removeProcessedOps(opIDs: string[]) {
  if (opIDs.length === 0) return;
  const db = await getLocalDatabase();
  const placeholders = opIDs.map(() => "?").join(",");
  await db.runAsync(`DELETE FROM sync_outbox WHERE op_id IN (${placeholders})`, ...opIDs);
}

async function bumpRetries(opIDs: string[]) {
  if (opIDs.length === 0) return;
  const db = await getLocalDatabase();
  for (const id of opIDs) {
    const nextRetryAt = new Date(Date.now() + 30000).toISOString();
    await db.runAsync(
        `UPDATE sync_outbox SET retry_count = retry_count + 1, next_retry_at = ? WHERE op_id = ?`,
        nextRetryAt, id
    );
  }
}

async function markDirtyCleared(entityType: SyncEntity, entityID: string) {
  const db = await getLocalDatabase();
  if (entityType === "note") {
    await db.runAsync(`UPDATE notes SET dirty = 0 WHERE id = ?`, entityID);
    return;
  }
  if (entityType === "folder") {
    await db.runAsync(`UPDATE folders SET dirty = 0 WHERE id = ?`, entityID);
    return;
  }
  await db.runAsync(`UPDATE tasks SET dirty = 0 WHERE id = ?`, entityID);
}

async function applyIDMappings(idMappings: { localId: string; serverId: string }[]) {
    for (const mapping of idMappings) {
        if (mapping.localId.startsWith("local_")) {
            await replaceLocalNoteID(mapping.localId, mapping.serverId);
            await replaceLocalFolderID(mapping.localId, mapping.serverId);
            await replaceLocalTaskID(mapping.localId, mapping.serverId);
        }
    }
}

export async function runSyncCycle(lastSyncAt: string | null): Promise<string> {
  await ensureOutboxForDirtyEntities();
  const ops = await listPendingOps();
  
  const storedLastSyncCursor = await getStoredLastSyncCursor();
  const effectiveLastSyncCursor = storedLastSyncCursor ?? lastSyncAt ?? null;

  const syncRequest: SyncRequest = {
    lastCursor: effectiveLastSyncCursor || undefined,
    ops: ops.map(op => ({
        id: op.op_id,
        type: op.op_type,
        entityType: op.entity_type,
        entityId: op.entity_id,
        payload: JSON.parse(op.payload_json || "{}")
    }))
  };

  try {
      const response = await apiClient.post<SyncResponse, SyncRequest>("/sync", syncRequest);
      
      if (response.idMappings.length > 0) {
          await applyIDMappings(response.idMappings);
      }

      if (response.folders.length > 0) await upsertFoldersLocal(response.folders);
      if (response.notes.length > 0) await upsertNotesLocal(response.notes);
      if (response.tasks.length > 0) await upsertTasksLocal(response.tasks);

      if (response.processedOpIds.length > 0) {
          await removeProcessedOps(response.processedOpIds);
      }

      const mapping = new Map<string, string>();
      for (const item of response.idMappings) {
        mapping.set(item.localId, item.serverId);
      }

      const processed = new Set(response.processedOpIds);
      for (const op of ops) {
        if (!processed.has(op.op_id)) {
          continue;
        }

        const mappedEntityID = mapping.get(op.entity_id) ?? op.entity_id;
        await markDirtyCleared(op.entity_type, mappedEntityID);
      }

      if (response.deleted.length > 0) {
        await applyRemoteDeletes(response.deleted);
      }

      await setStoredLastSyncCursor(response.nextCursor);
      return response.serverTime;
  } catch (error) {
      console.error("Mobile sync cycle failed:", error);
      await bumpRetries(ops.map(o => o.op_id));
      throw error;
  }
}

async function applyRemoteDeletes(deleted: SyncResponse["deleted"]) {
  const db = await getLocalDatabase();
  const now = new Date().toISOString();

  for (const item of deleted) {
    if (item.entityType === "note") {
      await db.runAsync(
        `UPDATE notes SET deleted_at = ?, updated_at = ?, dirty = 0 WHERE id = ?`,
        now,
        now,
        item.entityId,
      );
      continue;
    }
    if (item.entityType === "folder") {
      await db.runAsync(
        `UPDATE folders SET deleted_at = ?, updated_at = ?, dirty = 0 WHERE id = ?`,
        now,
        now,
        item.entityId,
      );
      await db.runAsync(
        `UPDATE notes SET folder_id = NULL WHERE folder_id = ? AND dirty = 0`,
        item.entityId,
      );
      continue;
    }
    await db.runAsync(
      `UPDATE tasks SET deleted_at = ?, updated_at = ?, dirty = 0 WHERE id = ?`,
      now,
      now,
      item.entityId,
    );
  }
}
