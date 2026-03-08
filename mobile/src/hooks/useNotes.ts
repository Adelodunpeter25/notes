import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type {
  CreateNotePayload,
  ListNotesParams,
  Note,
  UpdateNotePayload,
} from "@shared/notes";
import { apiClient } from "@/api/apiClient";
import { listNotesLocal, upsertNotesLocal } from "@/db";

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
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: notesKeys.list(params),
    queryFn: () => listNotesLocal(params),
  });

  const paramsKey = JSON.stringify(params ?? {});
  useEffect(() => {
    let cancelled = false;

    async function syncFromServer() {
      try {
        const remoteNotes = await apiClient.get<Note[]>(notesQuery(params));
        await upsertNotesLocal(remoteNotes);
        if (!cancelled) {
          queryClient.invalidateQueries({ queryKey: notesKeys.list(params) });
        }
      } catch {
        // Offline / unavailable server, keep local cache
      }
    }

    void syncFromServer();
    return () => {
      cancelled = true;
    };
  }, [paramsKey, queryClient]);

  return query;
}

export function useCreateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationKey: ['createNote'],
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
    mutationKey: ['updateNote'],
    mutationFn: ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) =>
      apiClient.patch<Note, UpdateNotePayload>(`/notes/${noteId}`, payload),
    onSuccess: (updatedNote, variables) => {
      queryClient.setQueriesData<Note[] | undefined>({ queryKey: notesKeys.all }, (currentNotes) => {
        if (!currentNotes) {
          return currentNotes;
        }

        return currentNotes.map((note) => (note.id === updatedNote.id ? updatedNote : note));
      });

      if (variables.payload.folderId !== undefined) {
        queryClient.invalidateQueries({ queryKey: ["folders"] });
      }

      // Always invalidate to ensure freshness across all filter variations
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
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
