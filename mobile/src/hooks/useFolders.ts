import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { CreateFolderPayload, Folder, RenameFolderPayload } from "@shared/folders";
import type { Note } from "@shared/notes";
import { apiClient } from "@/api/apiClient";
import {
  createFolderLocal,
  enqueueFolderDelete,
  enqueueFolderUpsert,
  listFoldersLocal,
  listNotesLocal,
  markFolderDeletedLocal,
  renameFolderLocal,
  upsertFoldersLocal,
  upsertFolderNotesLocal,
} from "@/db";

const folderKeys = {
  all: ["folders"] as const,
  list: () => [...folderKeys.all, "list"] as const,
  notes: (folderId: string) => [...folderKeys.all, "notes", folderId] as const,
};

export function useFoldersQuery() {
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: folderKeys.list(),
    queryFn: () => listFoldersLocal(),
  });

  useEffect(() => {
    let cancelled = false;

    async function syncFromServer() {
      try {
        const remoteFolders = await apiClient.get<Folder[]>("/folders/");
        await upsertFoldersLocal(remoteFolders);
        if (!cancelled) {
          queryClient.invalidateQueries({ queryKey: folderKeys.list() });
        }
      } catch {
        // Offline / unavailable server, keep local cache
      }
    }

    void syncFromServer();
    return () => {
      cancelled = true;
    };
  }, [queryClient]);

  return query;
}

export function useFolderNotesQuery(folderId: string | undefined) {
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: folderKeys.notes(folderId || ""),
    queryFn: () => listNotesLocal({ folderId }),
    enabled: Boolean(folderId),
  });

  useEffect(() => {
    if (!folderId) {
      return;
    }
    const activeFolderId = folderId;

    let cancelled = false;
    async function syncFromServer() {
      try {
        const remoteNotes = await apiClient.get<Note[]>(`/folders/${activeFolderId}/notes`);
        await upsertFolderNotesLocal(remoteNotes);
        if (!cancelled) {
          queryClient.invalidateQueries({ queryKey: folderKeys.notes(activeFolderId) });
        }
      } catch {
        // Offline / unavailable server, keep local cache
      }
    }

    void syncFromServer();
    return () => {
      cancelled = true;
    };
  }, [folderId, queryClient]);

  return query;
}

export function useCreateFolderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: CreateFolderPayload) => {
      const created = await createFolderLocal(payload.name);
      await enqueueFolderUpsert(created.id, { name: created.name });
      return created;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
    },
  });
}

export function useRenameFolderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ folderId, payload }: { folderId: string; payload: RenameFolderPayload }) => {
      const renamed = await renameFolderLocal(folderId, payload.name);
      if (!renamed) {
        throw new Error("Folder not found");
      }
      await enqueueFolderUpsert(folderId, { name: payload.name });
      return renamed;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
    },
  });
}

export function useDeleteFolderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (folderId: string) => {
      await markFolderDeletedLocal(folderId);
      await enqueueFolderDelete(folderId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export { folderKeys };
