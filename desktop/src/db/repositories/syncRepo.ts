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
  await enqueue("task", taskID, "upsert", payload);
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

async function markAllDirtyCleared() {
    const db = await getLocalDatabase();
    await db.execute(`UPDATE notes SET dirty = 0`);
    await db.execute(`UPDATE folders SET dirty = 0`);
    await db.execute(`UPDATE tasks SET dirty = 0`);
}

async function applyIDMappings(idMappings: { localId: string; serverId: string }[]) {
    // We don't know the entity type from the mapping alone here if we don't return it
    // But we can check prefixes or just try all
    for (const mapping of idMappings) {
        if (mapping.localId.startsWith("local_")) {
            // Try as note, folder, task
            await replaceLocalNoteID(mapping.localId, mapping.serverId);
            await replaceLocalFolderID(mapping.localId, mapping.serverId);
            await replaceLocalTaskID(mapping.localId, mapping.serverId);
        }
    }
}

export async function runSyncCycle(lastSyncAt: string | null): Promise<string> {
  const ops = await listPendingOps();
  
  const syncRequest: SyncRequest = {
    lastSyncAt: lastSyncAt || undefined,
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

      await markAllDirtyCleared();

      return response.serverTime;
  } catch (error) {
      console.error("Sync cycle failed:", error);
      await bumpRetries(ops.map(o => o.op_id));
      throw error;
  }
}
