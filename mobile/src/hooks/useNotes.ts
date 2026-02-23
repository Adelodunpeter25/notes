import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type {
  CreateNotePayload,
  ListNotesParams,
  Note,
  UpdateNotePayload,
} from "@shared/notes";
import { apiClient } from "@/api/apiClient";

const notesKeys = {
  all: ["notes"] as const,
  list: (params?: ListNotesParams) => [...notesKeys.all, "list", params] as const,
};

function notesQuery(params?: ListNotesParams): string {
  const query = new URLSearchParams();

  if (params?.folderId) {
    query.set("folderId", params.folderId);
  }
  if (params?.q) {
    query.set("q", params.q);
  }

  const suffix = query.toString();
  return suffix ? `/notes/?${suffix}` : "/notes/";
}

export function useNotesQuery(params?: ListNotesParams) {
  return useQuery({
    queryKey: notesKeys.list(params),
    queryFn: () => apiClient.get<Note[]>(notesQuery(params)),
  });
}

export function useCreateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: CreateNotePayload) => apiClient.post<Note, CreateNotePayload>("/notes/", payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export function useUpdateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) =>
      apiClient.patch<Note, UpdateNotePayload>(`/notes/${noteId}`, payload),
    onMutate: async ({ noteId, payload }) => {
      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: notesKeys.all });

      // Snapshot the previous value
      const previousTotalNotes = queryClient.getQueryData<Note[]>(notesKeys.all);

      // Optimistically update to the new value
      if (previousTotalNotes) {
        queryClient.setQueryData<Note[]>(
          notesKeys.all,
          previousTotalNotes.map((n) =>
            n.id === noteId ? { ...n, ...payload, updatedAt: new Date().toISOString() } : n
          )
        );
      }

      return { previousTotalNotes };
    },
    onError: (err, variables, context) => {
      if (context?.previousTotalNotes) {
        queryClient.setQueryData(notesKeys.all, context.previousTotalNotes);
      }
    },
    onSettled: (data, error, variables) => {
      // Still invalidate folders to keep counts in sync, but maybe not notes if we want to avoid the loop
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export function useDeleteNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (noteId: string) => apiClient.delete<void>(`/notes/${noteId}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export { notesKeys };
