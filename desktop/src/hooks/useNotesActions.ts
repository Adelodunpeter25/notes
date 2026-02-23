import type { UpdateNotePayload } from "@shared/notes";

import {
  useCreateNoteMutation,
  useDeleteNoteMutation,
  useUpdateNoteMutation,
} from "./useNotes";

type SaveNotePayload = {
  title: string;
  content: string;
  isPinned: boolean;
};

export function useNotesActions() {
  const createNoteMutation = useCreateNoteMutation();
  const updateNoteMutation = useUpdateNoteMutation();
  const deleteNoteMutation = useDeleteNoteMutation();

  async function createNote(folderId?: string | null) {
    return createNoteMutation.mutateAsync({
      title: "Untitled",
      content: "",
      ...(folderId ? { folderId } : {}),
    });
  }

  async function updateNote(noteId: string, payload: UpdateNotePayload) {
    return updateNoteMutation.mutateAsync({ noteId, payload });
  }

  async function saveSelectedNote(noteId: string | undefined, payload: SaveNotePayload) {
    if (!noteId) {
      return;
    }

    return updateNote(noteId, payload);
  }

  async function deleteNote(noteId: string) {
    return deleteNoteMutation.mutateAsync(noteId);
  }

  return {
    createNote,
    updateNote,
    saveSelectedNote,
    deleteNote,
    isCreating: createNoteMutation.isPending,
    isSaving: updateNoteMutation.isPending,
    isDeleting: deleteNoteMutation.isPending,
  };
}

