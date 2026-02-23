import { useEffect, useMemo, useRef, useState } from "react";
import type { Note } from "@shared/notes";

import { useDebounce } from "./useDebounce";
import { useFoldersQuery, useCreateFolderMutation, useRenameFolderMutation, useDeleteFolderMutation } from "./useFolders";
import { useNotesQuery } from "./useNotes";
import { useNotesActions } from "./useNotesActions";
import { isEmptyDraftNote } from "@/utils/noteContent";

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
  const createdDraftNoteIdsRef = useRef<Set<string>>(new Set());
  const notesByIdRef = useRef<Map<string, Note>>(new Map());
  const previousSelectedNoteIdRef = useRef<string | undefined>(selection.selectedNoteId);

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
    notes.forEach((note) => {
      notesByIdRef.current.set(note.id, note);
    });
  }, [notes]);

  useEffect(() => {
    autoSelectSuppressedRef.current = true;
  }, [selection.manualClearCount]);

  useEffect(() => {
    const previousSelectedId = previousSelectedNoteIdRef.current;
    const nextSelectedId = selection.selectedNoteId;

    if (
      previousSelectedId &&
      previousSelectedId !== nextSelectedId &&
      createdDraftNoteIdsRef.current.has(previousSelectedId)
    ) {
      const previousNote = notesByIdRef.current.get(previousSelectedId);
      if (previousNote && isEmptyDraftNote(previousNote)) {
        createdDraftNoteIdsRef.current.delete(previousSelectedId);
        notesByIdRef.current.delete(previousSelectedId);
        void notesActions.deleteNote(previousSelectedId);
      } else if (previousNote) {
        createdDraftNoteIdsRef.current.delete(previousSelectedId);
      }
    }

    previousSelectedNoteIdRef.current = nextSelectedId;
  }, [selection.selectedNoteId]);

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
    createdDraftNoteIdsRef.current.add(created.id);
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

  async function deleteNote(noteId: string) {
    createdDraftNoteIdsRef.current.delete(noteId);
    notesByIdRef.current.delete(noteId);
    return notesActions.deleteNote(noteId);
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
    deleteNote,
    createFolder,
    renameFolder,
    deleteFolder,
  };
}
