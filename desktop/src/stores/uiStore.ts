import { create } from "zustand";
import { persist } from "zustand/middleware";

type UiState = {
  activeView: "notes" | "tasks" | "trash";
  selectedFolderId: string | null;
  selectedNoteId: string | undefined;
  searchQuery: string;
  manualClearCount: number;
  isSidebarCollapsed: boolean;
  isSearchExpanded: boolean;
  isSearchModalOpen: boolean;
  tasksView: "list" | "kanban";
  setActiveView: (view: "notes" | "tasks" | "trash") => void;
  setSelectedFolderId: (folderId: string | null) => void;
  setSelectedNoteId: (noteId: string | undefined) => void;
  setSearchQuery: (value: string) => void;
  setIsSearchExpanded: (value: boolean) => void;
  setIsSearchModalOpen: (value: boolean) => void;
  clearSelectedNote: () => void;
  toggleSidebarCollapsed: () => void;
  setTasksView: (view: "list" | "kanban") => void;
  navigateToNote: (noteId: string, folderId: string | null) => void;
};

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      activeView: "notes",
      selectedFolderId: null,
      selectedNoteId: undefined,
      searchQuery: "",
      isSearchExpanded: false,
      isSearchModalOpen: false,
      manualClearCount: 0,
      isSidebarCollapsed: false,
      tasksView: "list",
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
      setIsSearchModalOpen: (value) => {
        set({ isSearchModalOpen: value });
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
      setTasksView: (view) => {
        set({ tasksView: view });
      },
      navigateToNote: (noteId, folderId) => {
        set({
          activeView: "notes",
          selectedNoteId: noteId,
          selectedFolderId: folderId,
          isSearchExpanded: false,
        });
      },
    }),
    {
      name: "notes-ui-state",
      partialize: (state) => ({
        selectedFolderId: state.selectedFolderId,
        selectedNoteId: state.selectedNoteId,
        isSidebarCollapsed: state.isSidebarCollapsed,
        tasksView: state.tasksView,
      }),
    }
  )
);
