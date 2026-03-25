import { useEffect, useMemo, useRef, useState } from "react";
import type { Note } from "@shared/notes";
import { useQueryClient } from "@tanstack/react-query";

import { useDebounce } from "./useDebounce";
import { useFoldersQuery, useCreateFolderMutation, useRenameFolderMutation, useDeleteFolderMutation } from "./useFolders";
import { syncPatchedNoteInCache, useNotesQuery } from "./useNotes";
import { useNotesActions } from "./useNotesActions";
import { isEmptyDraftNote } from "@shared-utils/noteContent";
import { useTasksQuery, useCreateTaskMutation, useUpdateTaskMutation, useDeleteTaskMutation, useToggleTaskMutation } from "./useTasks";

type DashboardSelectionState = {
  activeView: "notes" | "tasks";
  selectedFolderId: string | null;
  selectedNoteId: string | undefined;
  searchQuery: string;
  isSearchExpanded: boolean;
  manualClearCount: number;
  setActiveView: (view: "notes" | "tasks") => void;
  setSelectedFolderId: (folderId: string | null) => void;
  setSelectedNoteId: (noteId: string | undefined) => void;
};

export function useDashboardData(selection: DashboardSelectionState) {
  const queryClient = useQueryClient();
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

  const tasksQuery = useTasksQuery({
    q: debouncedSearchQuery.trim(),
  });
  const createTaskMutation = useCreateTaskMutation();
  const updateTaskMutation = useUpdateTaskMutation();
  const toggleTaskMutation = useToggleTaskMutation();
  const deleteTaskMutation = useDeleteTaskMutation();

  const pendingCreatedNoteIdRef = useRef<string | null>(null);
  const suppressAutoSelectRef = useRef(false);
  const createdDraftNoteIdsRef = useRef<Set<string>>(new Set());
  const draftCreatedAtRef = useRef<Map<string, number>>(new Map());
  const draftCleanupTimersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const renameFolderTimersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const notesByIdRef = useRef<Map<string, Note>>(new Map());
  const previousSelectedNoteIdRef = useRef<string | undefined>(selection.selectedNoteId);
  const selectedNoteIdRef = useRef<string | undefined>(selection.selectedNoteId);

  const [editingFolderId, setEditingFolderId] = useState<string | null>(null);

  const folders = foldersQuery.data ?? [];
  const notes = notesQuery.data ?? [];
  const tasks = tasksQuery.data ?? [];

  const selectedFolderName = useMemo(
    () => folders.find((folder) => folder.id === selection.selectedFolderId)?.name,
    [folders, selection.selectedFolderId],
  );

  const selectedNote = useMemo(() => {
    if (!selection.selectedNoteId) {
      return undefined;
    }

    return notes.find((note) => note.id === selection.selectedNoteId)
      ?? notesByIdRef.current.get(selection.selectedNoteId);
  }, [notes, selection.selectedNoteId]);

  useEffect(() => {
    notes.forEach((note) => {
      notesByIdRef.current.set(note.id, note);
    });
  }, [notes]);

  useEffect(() => {
    selectedNoteIdRef.current = selection.selectedNoteId;
  }, [selection.selectedNoteId]);

  useEffect(() => {
    suppressAutoSelectRef.current = true;
  }, [selection.manualClearCount]);

  useEffect(() => {
    const previousSelectedId = previousSelectedNoteIdRef.current;
    const nextSelectedId = selection.selectedNoteId;

    if (previousSelectedId && previousSelectedId !== nextSelectedId) {
      const existingTimer = draftCleanupTimersRef.current.get(previousSelectedId);
      if (existingTimer) {
        clearTimeout(existingTimer);
      }

      const timer = setTimeout(() => {
        if (selectedNoteIdRef.current === previousSelectedId) {
          return;
        }

        const previousNote = notesByIdRef.current.get(previousSelectedId);
        if (!previousNote) {
          return;
        }

        // Delete any empty note, not just newly created ones
        if (isEmptyDraftNote(previousNote)) {
          createdDraftNoteIdsRef.current.delete(previousSelectedId);
          draftCreatedAtRef.current.delete(previousSelectedId);
          notesByIdRef.current.delete(previousSelectedId);
          void notesActions.deleteNote(previousSelectedId);
          return;
        }

        // Clean up tracking for newly created notes
        if (createdDraftNoteIdsRef.current.has(previousSelectedId)) {
          createdDraftNoteIdsRef.current.delete(previousSelectedId);
          draftCreatedAtRef.current.delete(previousSelectedId);
        }
      }, 350);

      draftCleanupTimersRef.current.set(previousSelectedId, timer);
    }

    previousSelectedNoteIdRef.current = nextSelectedId;
  }, [selection.selectedNoteId, notesActions]);

  useEffect(() => {
    const isSearchActive = debouncedSearchQuery.trim().length > 0;
    const pendingCreatedId = pendingCreatedNoteIdRef.current;
    if (pendingCreatedId) {
      if (notes.some((note) => note.id === pendingCreatedId)) {
        if (selection.selectedNoteId !== pendingCreatedId) {
          selection.setSelectedNoteId(pendingCreatedId);
        }
        pendingCreatedNoteIdRef.current = null;
        suppressAutoSelectRef.current = false;
      }
      return;
    }

    if (!notesQuery.isSuccess || notesQuery.isFetching) {
      return;
    }

    if (selection.selectedNoteId) {
      suppressAutoSelectRef.current = false;
      if (!notes.some((note) => note.id === selection.selectedNoteId) && !isSearchActive) {
        selection.setSelectedNoteId(notes[0]?.id);
      }
      return;
    }

    if (suppressAutoSelectRef.current) {
      return;
    }

    if (notes.length > 0 && selection.activeView === "notes") {
      selection.setSelectedNoteId(notes[0].id);
    }
  }, [notes, selection.selectedNoteId, selection.setSelectedNoteId, notesQuery.isSuccess, notesQuery.isFetching, debouncedSearchQuery, selection.activeView]);

  useEffect(() => {
    return () => {
      for (const timer of draftCleanupTimersRef.current.values()) {
        clearTimeout(timer);
      }
      draftCleanupTimersRef.current.clear();
    };
  }, []);

  async function createNote() {
    const created = await notesActions.createNote(selection.selectedFolderId);
    pendingCreatedNoteIdRef.current = created.id;
    createdDraftNoteIdsRef.current.add(created.id);
    draftCreatedAtRef.current.set(created.id, Date.now());
    suppressAutoSelectRef.current = false;
    selection.setSelectedNoteId(created.id);
  }

  async function saveNote(noteId: string, payload: { title: string; content: string; isPinned: boolean }) {
    return notesActions.saveSelectedNote(noteId, payload);
  }

  function saveNoteLocal(noteId: string, payload: { title: string; content: string; isPinned: boolean }) {
    if (!noteId) {
      return;
    }

    syncPatchedNoteInCache(queryClient, noteId, payload);
  }

  async function createFolder() {
    const created = await createFolderMutation.mutateAsync({ name: "Untitled Folder" });
    selection.setSelectedFolderId(created.id);
    setEditingFolderId(created.id);
  }

  async function renameFolder(folderId: string, newName: string) {
    const trimmedName = newName.trim();
    if (!trimmedName) {
      setEditingFolderId(null);
      return;
    }

    const existingTimer = renameFolderTimersRef.current.get(folderId);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    const timer = setTimeout(() => {
      void renameFolderMutation.mutateAsync({ folderId, payload: { name: trimmedName } });
      renameFolderTimersRef.current.delete(folderId);
    }, 300);

    renameFolderTimersRef.current.set(folderId, timer);
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
    draftCreatedAtRef.current.delete(noteId);
    const timer = draftCleanupTimersRef.current.get(noteId);
    if (timer) {
      clearTimeout(timer);
      draftCleanupTimersRef.current.delete(noteId);
    }
    notesByIdRef.current.delete(noteId);
    return notesActions.deleteNote(noteId);
  }

  return {
    folders,
    notes,
    tasks,
    selectedFolderName,
    selectedNote,
    isFoldersLoading: foldersQuery.isLoading,
    isNotesLoading: notesQuery.isLoading || notesActions.isCreating,
    isTasksLoading: tasksQuery.isLoading,
    isSaving: notesActions.isSaving,
    isDeleting: notesActions.isDeleting,
    editingFolderId,
    setEditingFolderId,
    createNote,
    saveNote,
    saveNoteLocal,
    updateNote: notesActions.updateNote,
    deleteNote,
    createFolder,
    renameFolder,
    deleteFolder,
    createTask: (payload: any) => createTaskMutation.mutateAsync(payload),
    updateTask: (taskId: string, payload: any) => updateTaskMutation.mutateAsync({ id: taskId, payload }),
    deleteTask: (taskId: string) => deleteTaskMutation.mutateAsync(taskId),
    toggleTask: (task: any) => toggleTaskMutation.mutateAsync(task.id),
  };
}
