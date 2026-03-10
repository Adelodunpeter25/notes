import { create } from "zustand";
import { persist } from "zustand/middleware";

type UiState = {
  activeView: "notes" | "tasks";
  selectedFolderId: string | null;
  selectedNoteId: string | undefined;
  searchQuery: string;
  manualClearCount: number;
  isSidebarCollapsed: boolean;
  isSearchExpanded: boolean;
  setActiveView: (view: "notes" | "tasks") => void;
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
      activeView: "notes",
      selectedFolderId: null,
      selectedNoteId: undefined,
      searchQuery: "",
      isSearchExpanded: false,
      manualClearCount: 0,
      isSidebarCollapsed: false,
      setActiveView: (view) => {
        set({ activeView: view, selectedNoteId: undefined });
      },
      setSelectedFolderId: (folderId) => {
        set({
          activeView: "notes",
          selectedFolderId: folderId,
          selectedNoteId: undefined,
        });
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

