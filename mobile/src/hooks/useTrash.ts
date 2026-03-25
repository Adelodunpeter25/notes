import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { listTrash, restoreNote, permanentlyDeleteNote, clearTrash } from "@/db/repos/trashRepo";

export function useTrashQuery() {
  return useQuery({
    queryKey: ["trash"],
    queryFn: listTrash,
  });
}

export function useRestoreNoteMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => restoreNote(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trash"] });
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export function usePermanentlyDeleteNoteMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => permanentlyDeleteNote(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["trash"] }),
  });
}

export function useClearTrashMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: clearTrash,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["trash"] }),
  });
}
