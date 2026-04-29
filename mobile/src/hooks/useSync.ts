import { useCallback, useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";

import { apiClient } from "@/api/apiClient";
import { getDb } from "@/db/client";
import { buildSyncOps } from "@shared-utils/sync";
import { listNotes } from "@/db/repos/noteRepo";
import { listFolders } from "@/db/repos/folderRepo";
import { listTasks } from "@/db/repos/taskRepo";
import { listTrash } from "@/db/repos/trashRepo";
import { getSyncCursor, saveSyncCursor, clearSyncCursor } from "@/db/repos/syncStateRepo";
import { useAuthStore } from "@/stores/authStore";
import type { SyncResponse } from "@shared/sync";

const AUTO_SYNC_INTERVAL_MS = 15_000;

export function useSync(options?: { auto?: boolean }) {
  const queryClient = useQueryClient();
  const [isSyncing, setIsSyncing] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const syncingRef = useRef(false);
  const user = useAuthStore((state) => state.user);

  const syncNow = useCallback(async () => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    setIsSyncing(true);

    try {
      // Get cursor from database instead of AsyncStorage
      const cursor = await getSyncCursor();

      const [notes, folders, tasks, trashedNotes] = await Promise.all([
        listNotes().catch(() => []),
        listFolders().catch(() => []),
        listTasks().catch(() => []),
        listTrash().catch(() => []),
      ]);

      const allNotes = [...notes, ...trashedNotes];
      const ops = buildSyncOps(allNotes, folders, tasks, cursor);

      const response = await apiClient.post<SyncResponse>("/sync", { cursor, ops });

      await applyServerChanges(response);

      // Save cursor to database instead of AsyncStorage
      if (user?.id) {
        await saveSyncCursor(response.nextCursor, user.id);
      }
      
      await queryClient.invalidateQueries();
    } catch (err) {
      console.error("[sync] failed:", err);
    } finally {
      syncingRef.current = false;
      setIsSyncing(false);
    }
  }, [queryClient, user?.id]);

  const resetAndSync = useCallback(async () => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    setIsResetting(true);

    try {
      // Clear the sync cursor from database
      await clearSyncCursor();

      // Clear local database
      const db = getDb();
      await db.runAsync("DELETE FROM notes");
      await db.runAsync("DELETE FROM folders");
      await db.runAsync("DELETE FROM tasks");

      // Use force sync endpoint — always returns ALL data
      const response = await apiClient.post<SyncResponse>("/sync-force");

      await applyServerChangesForReset(response);

      // Save new cursor to database
      if (user?.id) {
        await saveSyncCursor(response.nextCursor, user.id);
      }
      
      await queryClient.invalidateQueries();
    } catch (err) {
      console.error("[reset and sync] failed:", err);
      throw err;
    } finally {
      syncingRef.current = false;
      setIsResetting(false);
    }
  }, [queryClient, user?.id]);

  const resetSyncCursor = useCallback(async () => {
    await clearSyncCursor();
  }, []);

  // Auto-sync: fire syncNow every 15 s when the option is enabled
  useEffect(() => {
    if (!options?.auto) return;
    const id = setInterval(() => {
      void syncNow();
    }, AUTO_SYNC_INTERVAL_MS);
    return () => clearInterval(id);
  }, [options?.auto, syncNow]);

  return { syncNow, resetAndSync, resetSyncCursor, isSyncing, isResetting };
}

async function applyServerChanges(response: SyncResponse) {
  const db = getDb();
  const now = new Date().toISOString();

  for (const tombstone of response.deleted) {
    if (tombstone.entityType === "note") {
      await db.runAsync("UPDATE notes SET deleted_at = ? WHERE id = ?", [tombstone.deletedAt, tombstone.entityId]).catch(() => {});
    } else if (tombstone.entityType === "folder") {
      await db.runAsync("UPDATE notes SET folder_id = NULL WHERE folder_id = ?", [tombstone.entityId]).catch(() => {});
      await db.runAsync("UPDATE folders SET deleted_at = ?, updated_at = ? WHERE id = ?", [tombstone.deletedAt, tombstone.deletedAt, tombstone.entityId]).catch(() => {});
    } else if (tombstone.entityType === "task") {
      await db.runAsync("UPDATE tasks SET deleted_at = ? WHERE id = ?", [tombstone.deletedAt, tombstone.entityId]).catch(() => {});
    }
  }

  for (const note of response.notes as any[]) {
    await db.runAsync(
      `INSERT INTO notes (id, user_id, folder_id, title, content, is_pinned, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         folder_id = excluded.folder_id,
         title = excluded.title,
         content = excluded.content,
         is_pinned = excluded.is_pinned,
         updated_at = excluded.updated_at
       WHERE excluded.updated_at > notes.updated_at`,
      [note.id, note.userId ?? null, note.folderId ?? null, note.title, note.content, note.isPinned ? 1 : 0, note.createdAt ?? now, note.updatedAt ?? now],
    ).catch(() => {});
  }

  for (const folder of response.folders as any[]) {
    await db.runAsync(
      `INSERT INTO folders (id, user_id, name, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         name = excluded.name,
         updated_at = excluded.updated_at
       WHERE excluded.updated_at > folders.updated_at`,
      [folder.id, folder.userId ?? null, folder.name, folder.createdAt ?? now, folder.updatedAt ?? now],
    ).catch(() => {});
  }

  for (const task of response.tasks as any[]) {
    await db.runAsync(
      `INSERT INTO tasks (id, user_id, title, description, is_completed, due_date, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         title = excluded.title,
         description = excluded.description,
         is_completed = excluded.is_completed,
         due_date = excluded.due_date,
         updated_at = excluded.updated_at
       WHERE excluded.updated_at > tasks.updated_at`,
      [task.id, task.userId ?? null, task.title, task.description, task.isCompleted ? 1 : 0, task.dueDate ?? null, task.createdAt ?? now, task.updatedAt ?? now],
    ).catch(() => {});
  }
}

async function applyServerChangesForReset(response: SyncResponse) {
  const db = getDb();
  const now = new Date().toISOString();

  // For reset, we don't need to handle tombstones since we cleared everything
  // Just insert all data from server without timestamp checks

  for (const note of response.notes as any[]) {
    await db.runAsync(
      `INSERT INTO notes (id, user_id, folder_id, title, content, is_pinned, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [note.id, note.userId ?? null, note.folderId ?? null, note.title, note.content, note.isPinned ? 1 : 0, note.createdAt ?? now, note.updatedAt ?? now],
    ).catch((err) => {
      console.error("Failed to insert note:", err);
    });
  }

  for (const folder of response.folders as any[]) {
    await db.runAsync(
      `INSERT INTO folders (id, user_id, name, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)`,
      [folder.id, folder.userId ?? null, folder.name, folder.createdAt ?? now, folder.updatedAt ?? now],
    ).catch((err) => {
      console.error("Failed to insert folder:", err);
    });
  }

  for (const task of response.tasks as any[]) {
    await db.runAsync(
      `INSERT INTO tasks (id, user_id, title, description, is_completed, due_date, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [task.id, task.userId ?? null, task.title, task.description, task.isCompleted ? 1 : 0, task.dueDate ?? null, task.createdAt ?? now, task.updatedAt ?? now],
    ).catch((err) => {
      console.error("Failed to insert task:", err);
    });
  }
}
