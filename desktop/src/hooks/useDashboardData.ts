import { useEffect, useMemo, useRef, useState } from "react";

import { useDebounce } from "./useDebounce";
import { useFoldersQuery, useCreateFolderMutation, useRenameFolderMutation, useDeleteFolderMutation } from "./useFolders";
import { useNotesQuery } from "./useNotes";
import { useNotesActions } from "./useNotesActions";

type DashboardSelectionState = {
  selectedFolderId: string | null;
  selectedNoteId: string | undefined;
  searchQuery: string;
  isSearchExpanded: boolean;
  manualClearCount: number;
  setSelectedFolderId: (folderId: string | null) => void;
  setSelectedNoteId: (noteId: string | undefined) => void;
};

export function useDashboardData(selection: DashboardSelectionState) {
  const debouncedSearchQuery = useDebounce(selection.searchQuery, 300);

  const foldersQuery = useFoldersQuery();
  const createFolderMutation = useCreateFolderMutation();
  const renameFolderMutation = useRenameFolderMutation();
  const deleteFolderMutation = useDeleteFolderMutation();

  const notesQuery = useNotesQuery({
    ...(selection.selectedFolderId ? { folderId: selection.selectedFolderId } : {}),
    ...(debouncedSearchQuery.trim() ? { q: debouncedSearchQuery.trim() } : {}),
  });
  const notesActions = useNotesActions();
  const pendingCreatedNoteIdRef = useRef<string | null>(null);
  const autoSelectSuppressedRef = useRef(false);

  const [editingFolderId, setEditingFolderId] = useState<string | null>(null);

  const folders = foldersQuery.data ?? [];
  const notes = notesQuery.data ?? [];

  const selectedFolderName = useMemo(
    () => folders.find((folder) => folder.id === selection.selectedFolderId)?.name,
    [folders, selection.selectedFolderId],
  );

  const selectedNote = useMemo(
    () => notes.find((note) => note.id === selection.selectedNoteId),
    [notes, selection.selectedNoteId],
  );

  useEffect(() => {
    autoSelectSuppressedRef.current = true;
  }, [selection.manualClearCount]);

  useEffect(() => {
    const pendingCreatedId = pendingCreatedNoteIdRef.current;
    if (pendingCreatedId) {
      if (notes.some((note) => note.id === pendingCreatedId)) {
        if (selection.selectedNoteId !== pendingCreatedId) {
          selection.setSelectedNoteId(pendingCreatedId);
        }
        pendingCreatedNoteIdRef.current = null;
        autoSelectSuppressedRef.current = false;
      }
      return;
    }

    if (!selection.selectedNoteId && autoSelectSuppressedRef.current) {
      return;
    }

    if (!selection.selectedNoteId && notes.length > 0) {
      selection.setSelectedNoteId(notes[0].id);
      return;
    }

    if (selection.selectedNoteId && !notes.some((note) => note.id === selection.selectedNoteId)) {
      selection.setSelectedNoteId(notes[0]?.id);
    }
  }, [notes, selection]);

  async function createNote() {
    const created = await notesActions.createNote(selection.selectedFolderId);
    pendingCreatedNoteIdRef.current = created.id;
    selection.setSelectedNoteId(created.id);
  }

  async function saveNote(payload: { title: string; content: string; isPinned: boolean }) {
    return notesActions.saveSelectedNote(selection.selectedNoteId, payload);
  }

  async function createFolder() {
    const created = await createFolderMutation.mutateAsync({ name: "Untitled Folder" });
    selection.setSelectedFolderId(created.id);
    setEditingFolderId(created.id);
  }

  async function renameFolder(folderId: string, newName: string) {
    if (newName.trim()) {
      await renameFolderMutation.mutateAsync({ folderId, payload: { name: newName.trim() } });
    }
    setEditingFolderId(null);
  }

  async function deleteFolder(folderId: string) {
    await deleteFolderMutation.mutateAsync(folderId);
    if (selection.selectedFolderId === folderId) {
      selection.setSelectedFolderId(null); // Return to All Notes
    }
  }

  return {
    folders,
    notes,
    selectedFolderName,
    selectedNote,
    isFoldersLoading: foldersQuery.isLoading,
    isNotesLoading: notesQuery.isLoading || notesActions.isCreating,
    isSaving: notesActions.isSaving,
    isDeleting: notesActions.isDeleting,
    editingFolderId,
    setEditingFolderId,
    createNote,
    saveNote,
    updateNote: notesActions.updateNote,
    deleteNote: notesActions.deleteNote,
    createFolder,
    renameFolder,
    deleteFolder,
  };
}
