import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { CreateFolderPayload, Folder, RenameFolderPayload } from "@shared/folders";
import type { Note } from "@shared/notes";
import { apiClient } from "@/api/apiClient";
import { listFoldersLocal, listNotesLocal, upsertFoldersLocal, upsertFolderNotesLocal } from "@/db";

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
    mutationFn: (payload: CreateFolderPayload) =>
      apiClient.post<Folder, CreateFolderPayload>("/folders/", payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
    },
  });
}

export function useRenameFolderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ folderId, payload }: { folderId: string; payload: RenameFolderPayload }) =>
      apiClient.patch<Folder, RenameFolderPayload>(`/folders/${folderId}`, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
    },
  });
}

export function useDeleteFolderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (folderId: string) => apiClient.delete<void>(`/folders/${folderId}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: folderKeys.all });
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export { folderKeys };
