import { apiClient } from "@/services";
import { getLocalDatabase } from "@/db/client";
import { upsertFoldersLocal, replaceLocalFolderID } from "@/db/repositories/foldersRepo";
import { upsertNotesLocal, replaceLocalNoteID } from "@/db/repositories/notesRepo";
import { upsertTasksLocal, replaceLocalTaskID } from "@/db/repositories/tasksRepo";
import type { UpdateNotePayload } from "@shared/notes";
import type { UpdateTaskPayload } from "@shared/tasks";
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
  return `op_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

const LAST_SYNC_KEY = "lastSyncCursor";

async function getStoredLastSyncCursor(): Promise<string | null> {
  const db = await getLocalDatabase();
  try {
    const rows = await db.select<Array<{ value: string | null }>>(
      `SELECT value FROM sync_state WHERE key = $1 LIMIT 1`,
      [LAST_SYNC_KEY],
    );
    if (!rows.length) {
      return null;
    }
    return rows[0].value ?? null;
  } catch {
    return null;
  }
}

async function setStoredLastSyncCursor(value: string) {
  const db = await getLocalDatabase();
  await db.execute(
    `
      INSERT INTO sync_state (key, value)
      VALUES ($1, $2)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    `,
    [LAST_SYNC_KEY, value],
  );
}

async function enqueue(entityType: SyncEntity, entityID: string, opType: SyncOpType, payload: any) {
  const db = await getLocalDatabase();
  
  if (opType === "upsert") {
    // Check if there's already a pending upsert for this entity
    const existing = await db.select<OutboxRow[]>(
      `SELECT op_id, retry_count, payload_json FROM sync_outbox WHERE entity_type = $1 AND entity_id = $2 AND op_type = 'upsert' LIMIT 1`,
      [entityType, entityID]
    );

    if (existing.length > 0) {
      const row = existing[0];
      const existingPayload = JSON.parse(row.payload_json || "{}");
      const mergedPayload = { ...existingPayload, ...payload };
      
      await db.execute(
        `UPDATE sync_outbox SET payload_json = $1, created_at = $2, retry_count = 0, next_retry_at = NULL WHERE op_id = $3`,
        [JSON.stringify(mergedPayload), nowISO(), row.op_id]
      );
      return;
    }
  }

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
  await enqueue("note", noteID, "upsert", payload);
}

export async function enqueueNoteDelete(noteID: string) {
  await enqueue("note", noteID, "delete", {});
}

export async function enqueueFolderUpsert(folderID: string, payload: { name: string }) {
  await enqueue("folder", folderID, "upsert", payload);
}

export async function enqueueFolderDelete(folderID: string) {
  await enqueue("folder", folderID, "delete", {});
}

export async function enqueueTaskUpsert(taskID: string, payload: UpdateTaskPayload) {
  await enqueue("task", taskID, "upsert", normalizeTaskPayload(payload));
}

export async function enqueueTaskDelete(taskID: string) {
  await enqueue("task", taskID, "delete", {});
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

async function ensureOutboxForDirtyEntities() {
  const db = await getLocalDatabase();

  const dirtyNotes = await db.select<
    Array<{
      id: string;
      folder_id: string | null;
      title: string;
      content: string;
      is_pinned: number;
      deleted_at: string | null;
    }>
  >(
    `
      SELECT id, folder_id, title, content, is_pinned, deleted_at
      FROM notes
      WHERE dirty = 1
    `,
  );

  for (const note of dirtyNotes) {
    await db.execute(
      `DELETE FROM sync_outbox WHERE entity_type = 'note' AND entity_id = $1`,
      [note.id],
    );

    if (note.deleted_at) {
      await enqueue("note", note.id, "delete", {});
    } else {
      await enqueue("note", note.id, "upsert", {
        title: note.title,
        content: note.content,
        isPinned: Boolean(note.is_pinned),
        ...(note.folder_id ? { folderId: note.folder_id } : {}),
      });
    }
  }

  const dirtyFolders = await db.select<
    Array<{ id: string; name: string; deleted_at: string | null }>
  >(
    `
      SELECT id, name, deleted_at
      FROM folders
      WHERE dirty = 1
    `,
  );

  for (const folder of dirtyFolders) {
    await db.execute(
      `DELETE FROM sync_outbox WHERE entity_type = 'folder' AND entity_id = $1`,
      [folder.id],
    );

    if (folder.deleted_at) {
      await enqueue("folder", folder.id, "delete", {});
    } else {
      await enqueue("folder", folder.id, "upsert", { name: folder.name });
    }
  }

  const dirtyTasks = await db.select<
    Array<{
      id: string;
      title: string;
      description: string;
      is_completed: number;
      due_date: string | null;
      deleted_at: string | null;
    }>
  >(
    `
      SELECT id, title, description, is_completed, due_date, deleted_at
      FROM tasks
      WHERE dirty = 1
    `,
  );

  for (const task of dirtyTasks) {
    await db.execute(
      `DELETE FROM sync_outbox WHERE entity_type = 'task' AND entity_id = $1`,
      [task.id],
    );

    if (task.deleted_at) {
      await enqueue("task", task.id, "delete", {});
    } else {
      await enqueue("task", task.id, "upsert", {
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
  const placeholders = opIDs.map((_, i) => `$${i + 1}`).join(",");
  await db.execute(`DELETE FROM sync_outbox WHERE op_id IN (${placeholders})`, opIDs);
}

async function bumpRetries(opIDs: string[]) {
  if (opIDs.length === 0) return;
  const db = await getLocalDatabase();
  for (const id of opIDs) {
    await db.execute(
        `UPDATE sync_outbox SET retry_count = retry_count + 1, next_retry_at = $1 WHERE op_id = $2`,
        [new Date(Date.now() + 30000).toISOString(), id]
    );
  }
}

async function markDirtyCleared(entityType: SyncEntity, entityID: string) {
  const db = await getLocalDatabase();
  if (entityType === "note") {
    await db.execute(`UPDATE notes SET dirty = 0 WHERE id = $1`, [entityID]);
    return;
  }
  if (entityType === "folder") {
    await db.execute(`UPDATE folders SET dirty = 0 WHERE id = $1`, [entityID]);
    return;
  }
  await db.execute(`UPDATE tasks SET dirty = 0 WHERE id = $1`, [entityID]);
}

async function applyIDMappings(idMappings: { localId: string; serverId: string }[]) {
  const db = await getLocalDatabase();

  for (const mapping of idMappings) {
    if (!mapping.localId.startsWith("local_")) {
      continue;
    }

    const [noteMatch, folderMatch, taskMatch] = await Promise.all([
      db.select<Array<{ id: string }>>(`SELECT id FROM notes WHERE id = $1 LIMIT 1`, [mapping.localId]),
      db.select<Array<{ id: string }>>(`SELECT id FROM folders WHERE id = $1 LIMIT 1`, [mapping.localId]),
      db.select<Array<{ id: string }>>(`SELECT id FROM tasks WHERE id = $1 LIMIT 1`, [mapping.localId]),
    ]);

    if (noteMatch.length) {
      await replaceLocalNoteID(mapping.localId, mapping.serverId);
    }
    if (folderMatch.length) {
      await replaceLocalFolderID(mapping.localId, mapping.serverId);
    }
    if (taskMatch.length) {
      await replaceLocalTaskID(mapping.localId, mapping.serverId);
    }
  }
}

export async function runSyncCycle(): Promise<string> {
  await ensureOutboxForDirtyEntities();
  const ops = await listPendingOps();
  const lastCursor = await getStoredLastSyncCursor();
  
  const syncRequest: SyncRequest = {
    lastCursor: lastCursor || undefined,
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
      
      // Update local IDs before upserting remote changes
      if (response.idMappings.length > 0) {
          await applyIDMappings(response.idMappings);
      }

      // Upsert everything returned from server
      if (response.folders.length > 0) await upsertFoldersLocal(response.folders);
      if (response.notes.length > 0) await upsertNotesLocal(response.notes);
      if (response.tasks.length > 0) await upsertTasksLocal(response.tasks);

      // Remove successful ops
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
      console.error("Sync cycle failed:", error);
      await bumpRetries(ops.map(o => o.op_id));
      throw error;
  }
}

async function applyRemoteDeletes(deleted: SyncResponse["deleted"]) {
  const db = await getLocalDatabase();
  const now = new Date().toISOString();

  for (const item of deleted) {
    if (item.entityType === "note") {
      await db.execute(
        `UPDATE notes SET deleted_at = $1, updated_at = $2, dirty = 0 WHERE id = $3`,
        [now, now, item.entityId],
      );
      continue;
    }
    if (item.entityType === "folder") {
      await db.execute(
        `UPDATE folders SET deleted_at = $1, updated_at = $2, dirty = 0 WHERE id = $3`,
        [now, now, item.entityId],
      );
      await db.execute(
        `UPDATE notes SET folder_id = NULL WHERE folder_id = $1 AND dirty = 0`,
        [item.entityId],
      );
      continue;
    }
    await db.execute(
      `UPDATE tasks SET deleted_at = $1, updated_at = $2, dirty = 0 WHERE id = $3`,
      [now, now, item.entityId],
    );
  }
}
