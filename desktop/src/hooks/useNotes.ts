import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";
import type { Note, CreateNotePayload, UpdateNotePayload } from "@shared/notes";

export function useNotesQuery(params?: { folderId?: string; q?: string }) {
  return useQuery({
    queryKey: ["notes", params],
    queryFn: () =>
      invoke<Note[]>("list_notes", {
        folderId: params?.folderId,
        q: params?.q,
      }),
  });
}

export function useCreateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: CreateNotePayload) =>
      invoke<Note>("create_note", { payload }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export function useUpdateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: UpdateNotePayload }) =>
      invoke<Note>("update_note", { id, payload }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notes"] });
    },
  });
}

export function useDeleteNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => invoke<void>("delete_note", { id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notes"] });
      queryClient.invalidateQueries({ queryKey: ["trash"] });
    },
  });
}

export function syncPatchedNoteInCache(
  queryClient: ReturnType<typeof useQueryClient>,
  noteId: string,
  patch: Partial<Note>
) {
  queryClient.setQueriesData<Note[]>(
    { queryKey: ["notes"] },
    (old) => {
      if (!old) return old;
      return old.map((note) =>
        note.id === noteId ? { ...note, ...patch } : note
      );
    }
  );
}
