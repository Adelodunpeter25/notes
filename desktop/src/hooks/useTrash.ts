import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";
import type { Note } from "@shared/notes";

export function useTrashQuery() {
  return useQuery({
    queryKey: ["trash"],
    queryFn: () => invoke<Note[]>("list_trash"),
  });
}

export function useRestoreNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => invoke<Note>("restore_note", { id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trash"] });
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export function usePermanentlyDeleteNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => invoke<void>("permanently_delete_note", { id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trash"] });
    },
  });
}

export function useClearTrashMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => invoke<void>("clear_trash"),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trash"] });
    },
  });
}
