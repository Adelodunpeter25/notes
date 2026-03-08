import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type {
  CreateNotePayload,
  ListNotesParams,
  Note,
  UpdateNotePayload,
} from "@shared/notes";
import { apiClient } from "@/api/apiClient";
import {
  createNoteLocal,
  enqueueNoteDelete,
  enqueueNoteUpsert,
  listNotesLocal,
  markNoteDeletedLocal,
  updateNoteLocal,
  upsertNotesLocal,
} from "@/db";

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
    mutationFn: async (payload: CreateNotePayload) => {
      const created = await createNoteLocal(payload);
      await enqueueNoteUpsert(created.id, {
        title: created.title,
        content: created.content,
        isPinned: created.isPinned,
        ...(created.folderId ? { folderId: created.folderId } : {}),
      });
      return created;
    },
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
    mutationFn: async ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) => {
      const updated = await updateNoteLocal(noteId, payload);
      if (!updated) {
        throw new Error("Note not found");
      }
      await enqueueNoteUpsert(noteId, payload);
      return updated;
    },
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

      queryClient.invalidateQueries({ queryKey: notesKeys.all });
    },
  });
}

export function useDeleteNoteMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (noteId: string) => {
      await markNoteDeletedLocal(noteId);
      await enqueueNoteDelete(noteId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders"] });
    },
  });
}

export { notesKeys };
