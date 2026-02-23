import { useMemo, useState } from "react";

import { useDebounce } from "./useDebounce";
import {
  useCreateFolderMutation,
  useDeleteFolderMutation,
  useFoldersQuery,
  useRenameFolderMutation,
} from "./useFolders";
import {
  useCreateNoteMutation,
  useDeleteNoteMutation,
  useNotesQuery,
  useUpdateNoteMutation,
} from "./useNotes";

export function useDashboardData() {
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
  const [selectedNoteId, setSelectedNoteId] = useState<string | undefined>(undefined);
  const [searchQuery, setSearchQuery] = useState("");

  const debouncedSearchQuery = useDebounce(searchQuery, 250);

  const foldersQuery = useFoldersQuery();
  const notesQuery = useNotesQuery({
    folderId: selectedFolderId || undefined,
    q: debouncedSearchQuery || undefined,
  });

  const createNoteMutation = useCreateNoteMutation();
  const updateNoteMutation = useUpdateNoteMutation();
  const deleteNoteMutation = useDeleteNoteMutation();
  const createFolderMutation = useCreateFolderMutation();
  const renameFolderMutation = useRenameFolderMutation();
  const deleteFolderMutation = useDeleteFolderMutation();

  const selectedNote = useMemo(
    () => notesQuery.data?.find((note) => note.id === selectedNoteId),
    [notesQuery.data, selectedNoteId],
  );

  const selectedFolderName = useMemo(
    () => foldersQuery.data?.find((folder) => folder.id === selectedFolderId)?.name ?? "All Notes",
    [foldersQuery.data, selectedFolderId],
  );

  const createNote = async () => {
    const created = await createNoteMutation.mutateAsync({
      folderId: selectedFolderId || undefined,
      title: "Untitled",
      content: "",
      isPinned: false,
    });
    setSelectedNoteId(created.id);
    return created;
  };

  const saveNote = async (
    noteId: string,
    payload: { title?: string; content?: string; isPinned?: boolean; folderId?: string },
  ) => {
    return updateNoteMutation.mutateAsync({ noteId, payload });
  };

  const deleteNote = async (noteId: string) => {
    await deleteNoteMutation.mutateAsync(noteId);
    if (selectedNoteId === noteId) {
      setSelectedNoteId(undefined);
    }
  };

  const createFolder = async (name: string) => {
    const created = await createFolderMutation.mutateAsync({ name });
    return created;
  };

  const renameFolder = async (folderId: string, name: string) => {
    return renameFolderMutation.mutateAsync({ folderId, payload: { name } });
  };

  const deleteFolder = async (folderId: string) => {
    await deleteFolderMutation.mutateAsync(folderId);
    if (selectedFolderId === folderId) {
      setSelectedFolderId(null);
    }
  };

  return {
    notes: notesQuery.data ?? [],
    folders: foldersQuery.data ?? [],
    selectedNote,
    selectedFolderId,
    selectedFolderName,
    selectedNoteId,
    searchQuery,
    setSearchQuery,
    setSelectedFolderId,
    setSelectedNoteId,
    isNotesLoading: notesQuery.isLoading,
    isFoldersLoading: foldersQuery.isLoading,
    isNotesRefreshing: notesQuery.isRefetching,
    isFoldersRefreshing: foldersQuery.isRefetching,
    refetchNotes: notesQuery.refetch,
    refetchFolders: foldersQuery.refetch,
    createNote,
    saveNote,
    deleteNote,
    createFolder,
    renameFolder,
    deleteFolder,
    isCreatingNote: createNoteMutation.isPending,
    isUpdatingNote: updateNoteMutation.isPending,
    isDeletingNote: deleteNoteMutation.isPending,
    isCreatingFolder: createFolderMutation.isPending,
    isRenamingFolder: renameFolderMutation.isPending,
    isDeletingFolder: deleteFolderMutation.isPending,
  };
}
