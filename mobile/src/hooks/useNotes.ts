import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { listNotes, getNote, createNote, updateNote, deleteNote } from "@/db/repos/noteRepo";
import type { CreateNotePayload, UpdateNotePayload } from "@shared/notes";

export function useNotesQuery(params?: { folderId?: string; q?: string }) {
  return useQuery({
    queryKey: ["notes", params],
    queryFn: () => listNotes(params),
  });
}

export function useFolderNotesQuery(folderId: string) {
  return useQuery({
    queryKey: ["notes", { folderId }],
    queryFn: () => listNotes({ folderId }),
    enabled: !!folderId,
  });
}

export function useNoteQuery(id: string) {
  return useQuery({
    queryKey: ["notes", id],
    queryFn: () => getNote(id),
    enabled: !!id,
  });
}

export function useCreateNoteMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: CreateNotePayload) => createNote(payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notes"] }),
  });
}

export function useUpdateNoteMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) =>
      updateNote(noteId, payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notes"] }),
  });
}

export function useDeleteNoteMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteNote(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notes"] });
      queryClient.invalidateQueries({ queryKey: ["trash"] });
    },
  });
}
