import { create } from "zustand";
import { persist } from "zustand/middleware";

type UiState = {
  selectedFolderId: string | null;
  selectedNoteId: string | undefined;
  searchQuery: string;
  manualClearCount: number;
  isSidebarCollapsed: boolean;
  isSearchExpanded: boolean;
  setSelectedFolderId: (folderId: string | null) => void;
  setSelectedNoteId: (noteId: string | undefined) => void;
  setSearchQuery: (value: string) => void;
  setIsSearchExpanded: (value: boolean) => void;
  clearSelectedNote: () => void;
  toggleSidebarCollapsed: () => void;
};

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      selectedFolderId: null,
      selectedNoteId: undefined,
      searchQuery: "",
      isSearchExpanded: false,
      manualClearCount: 0,
      isSidebarCollapsed: false,
      setSelectedFolderId: (folderId) => {
        set({ selectedFolderId: folderId, selectedNoteId: undefined });
      },
      setSelectedNoteId: (noteId) => {
        set({ selectedNoteId: noteId });
      },
      setSearchQuery: (value) => {
        set({ searchQuery: value });
      },
      setIsSearchExpanded: (value) => {
        set({ isSearchExpanded: value });
      },
      clearSelectedNote: () => {
        set((state) => ({
          selectedNoteId: undefined,
          manualClearCount: state.manualClearCount + 1,
        }));
      },
      toggleSidebarCollapsed: () => {
        set((state) => ({ isSidebarCollapsed: !state.isSidebarCollapsed }));
      },
    }),
    {
      name: "notes-ui-state",
      partialize: (state) => ({
        selectedFolderId: state.selectedFolderId,
        selectedNoteId: state.selectedNoteId,
        isSidebarCollapsed: state.isSidebarCollapsed,
      }),
    }
  )
);

