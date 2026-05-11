import { useCallback, useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";

import { apiClient } from "@/services/apiClient";
import { useAuthStore } from "@/stores/authStore";
import { buildSyncOps } from "@shared-utils/sync";
import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import type { SyncResponse } from "@shared/sync";

export function useSync(options?: { auto?: boolean }) {
  const queryClient = useQueryClient();
  const [isSyncing, setIsSyncing] = useState(false);
  const syncingRef = useRef(false);
  const user = useAuthStore((state) => state.user);

  const syncNow = useCallback(async () => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    setIsSyncing(true);

    try {
      // Get cursor from database instead of localStorage
      const cursor = await invoke<string | null>("get_sync_cursor");

      const [notes, folders] = await Promise.all([
        invoke<Note[]>("list_notes").catch(() => [] as Note[]),
        invoke<Folder[]>("list_folders").catch(() => [] as Folder[]),
      ]);

      // Include trashed notes so deletes sync
      const trashedNotes = await invoke<Note[]>("list_trash").catch(() => [] as Note[]);
      const allNotes = [...notes, ...trashedNotes];

      const ops = buildSyncOps(allNotes, folders, [], cursor);

      const response = await apiClient.post<SyncResponse>("/sync", { cursor, ops });

      // Apply server changes to local SQLite
      await applyServerChanges(response);

      // Save cursor to database
      await invoke("save_sync_cursor", {
        cursor: response.nextCursor,
        userId: user?.id ?? null,
      });

      // Invalidate all queries so UI reflects changes
      await queryClient.invalidateQueries();
    } catch (err) {
      console.error("[sync] failed:", err);
    } finally {
      syncingRef.current = false;
      setIsSyncing(false);
    }
  }, [queryClient, user?.id]);

  const resetSyncCursor = useCallback(async () => {
    await invoke("clear_sync_cursor");
  }, []);

  useEffect(() => {
    if (!options?.auto) return;
    const id = setInterval(() => void syncNow(), 45_000);
    return () => clearInterval(id);
  }, [options?.auto, syncNow]);

  return { syncNow, isSyncing, resetSyncCursor };
}

async function applyServerChanges(response: SyncResponse) {
  // Apply tombstones first
  await Promise.all(response.deleted.map(async (tombstone) => {
    if (tombstone.entityType === "note") {
      await invoke("delete_note", { id: tombstone.entityId }).catch((e) => console.warn("[sync] delete_note failed", e));
    }
  }));

  await Promise.all([
    ...(response.notes as any[]).map((note) =>
      invoke("upsert_note", { note }).catch((e) => console.warn("[sync] upsert_note failed", note.id, e))
    ),
    ...(response.folders as any[]).map((folder) =>
      invoke("upsert_folder", { folder }).catch((e) => console.warn("[sync] upsert_folder failed", folder.id, e))
    ),
  ]);
}
