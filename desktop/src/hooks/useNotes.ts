import { QueryClient, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type {
  CreateNotePayload,
  ListNotesParams,
  Note,
  UpdateNotePayload,
} from "@shared/notes";
import {
  createNoteLocal,
  enqueueNoteDelete,
  enqueueNoteUpsert,
  listNotesLocal,
  markNoteDeletedLocal,
  updateNoteLocal,
} from "@/db";

const notesKeys = {
  all: ["notes"] as const,
  list: (params?: ListNotesParams) => [...notesKeys.all, "list", params] as const,
};

function getListParamsFromQueryKey(queryKey: readonly unknown[]): ListNotesParams | undefined {
  if (!Array.isArray(queryKey) || queryKey.length < 3) {
    return undefined;
  }

  if (queryKey[0] !== notesKeys.all[0] || queryKey[1] !== "list") {
    return undefined;
  }

  const params = queryKey[2];
  return (params && typeof params === "object") ? (params as ListNotesParams) : undefined;
}

function noteMatchesListParams(note: Note, params?: ListNotesParams): boolean {
  if (params?.folderId && note.folderId !== params.folderId) {
    return false;
  }

  if (params?.q) {
    const query = params.q.toLowerCase();
    const title = note.title.toLowerCase();
    const content = note.content.toLowerCase();
    if (!title.includes(query) && !content.includes(query)) {
      return false;
    }
  }

  return true;
}

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

export function useNotesQuery(params?: ListNotesParams) {
  const query = useQuery({
    queryKey: notesKeys.list(params),
    queryFn: () => listNotesLocal(params),
  });

  return query;
}

export function useCreateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationKey: ["createNote"],
    mutationFn: async (payload: CreateNotePayload) => {
      const created = await createNoteLocal(payload);
      try {
        await enqueueNoteUpsert(created.id, {
          title: created.title,
          content: created.content,
          isPinned: created.isPinned,
          ...(created.folderId ? { folderId: created.folderId } : {}),
        });
      } catch (error) {
        console.error("Failed to enqueue note create:", error);
      }
      return created;
    },
    onSuccess: (created) => {
      const noteLists = queryClient.getQueriesData<Note[]>({ queryKey: notesKeys.all });
      for (const [queryKey, current] of noteLists) {
        if (!Array.isArray(current)) continue;
        const params = getListParamsFromQueryKey(queryKey);
        if (!noteMatchesListParams(created, params)) continue;
        queryClient.setQueryData<Note[]>(queryKey, sortNotes([created, ...current]));
      }
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export function useUpdateNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationKey: ["updateNote"],
    mutationFn: async ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) => {
      const updated = await updateNoteLocal(noteId, payload);
      if (!updated) throw new Error("note not found");
      try {
        await enqueueNoteUpsert(noteId, payload);
      } catch (error) {
        console.error("Failed to enqueue note update:", error);
      }
      return updated;
    },
    onMutate: async ({ noteId, payload }) => {
      const optimisticUpdatedAt = new Date().toISOString();
      syncPatchedNoteInCache(queryClient, noteId, payload, optimisticUpdatedAt);
      return { optimisticUpdatedAt };
    },
    onSuccess: (note, variables) => {
      syncPatchedNoteInCache(queryClient, variables.noteId, note, note.updatedAt ?? new Date().toISOString());
      if (variables.payload.folderId !== undefined) {
        queryClient.invalidateQueries({ queryKey: notesKeys.all });
      }
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export function useDeleteNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (noteId: string) => {
      await markNoteDeletedLocal(noteId);
      try {
        await enqueueNoteDelete(noteId);
      } catch (error) {
        console.error("Failed to enqueue note delete:", error);
      }
    },
    onMutate: async (noteId) => {
      let removedNote: Note | undefined;
      const noteLists = queryClient.getQueriesData<Note[]>({ queryKey: notesKeys.all });
      for (const [, current] of noteLists) {
        if (!Array.isArray(current)) continue;
        const found = current.find((note) => note.id === noteId);
        if (found) {
          removedNote = found;
          break;
        }
      }

      for (const [queryKey, current] of noteLists) {
        if (!Array.isArray(current)) continue;
        queryClient.setQueryData<Note[]>(queryKey, current.filter((note) => note.id !== noteId));
      }

      return { removedNote };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export { notesKeys };
