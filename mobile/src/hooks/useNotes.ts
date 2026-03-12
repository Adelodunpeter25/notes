import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

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
    mutationKey: ['createNote'],
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
        console.error("Failed to enqueue note create for sync:", error);
      }
      return created;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders"] });
      queryClient.invalidateQueries({ queryKey: ["folders", "notes"] });
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
      try {
        await enqueueNoteUpsert(noteId, payload);
      } catch (error) {
        console.error("Failed to enqueue note update for sync:", error);
      }
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
        queryClient.refetchQueries({ queryKey: notesKeys.all });
      }

      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.refetchQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders", "notes"] });
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
        console.error("Failed to enqueue note delete for sync:", error);
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notesKeys.all });
      queryClient.invalidateQueries({ queryKey: ["folders"] });
      queryClient.invalidateQueries({ queryKey: ["folders", "notes"] });
    },
  });
}

export { notesKeys };
