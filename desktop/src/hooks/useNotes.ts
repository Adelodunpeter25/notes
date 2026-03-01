import { QueryClient, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type {
  CreateNotePayload,
  ListNotesParams,
  Note,
  UpdateNotePayload,
} from "@shared/notes";
import { apiClient } from "@/services";

const notesKeys = {
  all: ["notes"] as const,
  list: (params?: ListNotesParams) => [...notesKeys.all, "list", params] as const,
};

function getNoteTimestamp(note: Note): number {
  const value = note.updatedAt ?? note.createdAt;
  if (!value) {
    return 0;
  }

  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function sortNotes(notes: Note[]): Note[] {
  return [...notes].sort((left, right) => {
    if (left.isPinned !== right.isPinned) {
      return left.isPinned ? -1 : 1;
    }

    return getNoteTimestamp(right) - getNoteTimestamp(left);
  });
}

function patchNotesList(notes: Note[] | undefined, noteId: string, payload: UpdateNotePayload, updatedAt: string) {
  if (!notes || notes.length === 0) {
    return notes;
  }

  let hasMatch = false;
  const next = notes.map((note) => {
    if (note.id !== noteId) {
      return note;
    }

    hasMatch = true;
    return {
      ...note,
      ...payload,
      updatedAt,
    };
  });

  if (!hasMatch) {
    return notes;
  }

  return sortNotes(next);
}

export function syncPatchedNoteInCache(
  queryClient: QueryClient,
  noteId: string,
  payload: UpdateNotePayload,
  updatedAt = new Date().toISOString(),
) {
  queryClient.setQueriesData<Note[]>({ queryKey: notesKeys.all }, (previous) =>
    patchNotesList(previous, noteId, payload, updatedAt),
  );
}

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
    onMutate: async ({ noteId, payload }) => {
      const optimisticUpdatedAt = new Date().toISOString();

      syncPatchedNoteInCache(queryClient, noteId, payload, optimisticUpdatedAt);

      return { optimisticUpdatedAt };
    },
    onSuccess: (note, variables) => {
      syncPatchedNoteInCache(queryClient, variables.noteId, note, note.updatedAt ?? new Date().toISOString());

      if (variables.payload.folderId !== undefined) {
        queryClient.invalidateQueries({ queryKey: notesKeys.all });
        queryClient.invalidateQueries({ queryKey: ["folders"] });
      }
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
