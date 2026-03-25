import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { listFolders, getFolder, createFolder, renameFolder, deleteFolder } from "@/db/repos/folderRepo";
import type { CreateFolderPayload, RenameFolderPayload } from "@shared/folders";

export function useFoldersQuery() {
  return useQuery({
    queryKey: ["folders"],
    queryFn: listFolders,
  });
}

export function useFolderQuery(id: string) {
  return useQuery({
    queryKey: ["folders", id],
    queryFn: () => getFolder(id),
    enabled: !!id,
  });
}

export function useCreateFolderMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: CreateFolderPayload) => createFolder(payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["folders"] }),
  });
}

export function useRenameFolderMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ folderId, payload }: { folderId: string; payload: RenameFolderPayload }) =>
      renameFolder(folderId, payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["folders"] }),
  });
}

export function useDeleteFolderMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteFolder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["folders"] });
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}
