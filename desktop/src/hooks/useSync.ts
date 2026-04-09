import { useCallback, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";

import { apiClient } from "@/services/apiClient";
import { buildSyncOps } from "@shared-utils/sync";
import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import type { Task } from "@shared/tasks";
import type { SyncResponse } from "@shared/sync";

const CURSOR_KEY = "notes_sync_cursor";

export function useSync(_options?: { auto?: boolean }) {
  const queryClient = useQueryClient();
  const [isSyncing, setIsSyncing] = useState(false);
  const syncingRef = useRef(false);

  const syncNow = useCallback(async () => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    setIsSyncing(true);

    try {
      const cursor = localStorage.getItem(CURSOR_KEY);

      const [notes, folders, tasks] = await Promise.all([
        invoke<Note[]>("list_notes").catch(() => [] as Note[]),
        invoke<Folder[]>("list_folders").catch(() => [] as Folder[]),
        invoke<Task[]>("list_tasks").catch(() => [] as Task[]),
      ]);

      // Include trashed notes and tasks so deletes sync
      const [trashedNotes, trashedTasks] = await Promise.all([
        invoke<Note[]>("list_trash").catch(() => [] as Note[]),
        invoke<Task[]>("list_deleted_tasks").catch(() => [] as Task[]),
      ]);
      const allNotes = [...notes, ...trashedNotes];
      const allTasks = [...tasks, ...trashedTasks];

      const ops = buildSyncOps(allNotes, folders, allTasks, cursor);

      const response = await apiClient.post<SyncResponse>("/sync", { cursor, ops });

      // Apply server changes to local SQLite
      await applyServerChanges(response);

      localStorage.setItem(CURSOR_KEY, response.nextCursor);

      // Invalidate all queries so UI reflects changes
      await queryClient.invalidateQueries();
    } catch (err) {
      console.error("[sync] failed:", err);
    } finally {
      syncingRef.current = false;
      setIsSyncing(false);
    }
  }, [queryClient]);

  const resetSyncCursor = useCallback(() => {
    localStorage.removeItem(CURSOR_KEY);
  }, []);

  return { syncNow, isSyncing, resetSyncCursor };
}

async function applyServerChanges(response: SyncResponse) {
  // Apply tombstones first
  for (const tombstone of response.deleted) {
    if (tombstone.entityType === "note") {
      await invoke("delete_note", { id: tombstone.entityId }).catch(() => {});
    } else if (tombstone.entityType === "task") {
      await invoke("delete_task", { id: tombstone.entityId }).catch(() => {});
    }
    // folders are hard-deleted on server, skip
  }

  // Upsert notes
  for (const note of response.notes as any[]) {
    await invoke("upsert_note", { note }).catch(() => {});
  }

  // Upsert folders
  for (const folder of response.folders as any[]) {
    await invoke("upsert_folder", { folder }).catch(() => {});
  }

  // Upsert tasks
  for (const task of response.tasks as any[]) {
    await invoke("upsert_task", { task }).catch(() => {});
  }
}
