import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { CreateFolderPayload, Folder, RenameFolderPayload } from "@shared/folders";
import type { Note } from "@shared/notes";
import { apiClient } from "@/api/apiClient";

const folderKeys = {
  all: ["folders"] as const,
  list: () => [...folderKeys.all, "list"] as const,
  notes: (folderId: string) => [...folderKeys.all, "notes", folderId] as const,
};

export function useFoldersQuery() {
  return useQuery({
    queryKey: folderKeys.list(),
    queryFn: () => apiClient.get<Folder[]>("/folders/"),
  });
}

export function useFolderNotesQuery(folderId: string | undefined) {
  return useQuery({
    queryKey: folderKeys.notes(folderId || ""),
    queryFn: () => apiClient.get<Note[]>(`/folders/${folderId}/notes`),
    enabled: Boolean(folderId),
  });
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
