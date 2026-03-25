import { useUiStore } from "@/stores";

export function useDashboardSelection() {
  const activeView = useUiStore((state) => state.activeView);
  const selectedFolderId = useUiStore((state) => state.selectedFolderId);
  const selectedNoteId = useUiStore((state) => state.selectedNoteId);
  const searchQuery = useUiStore((state) => state.searchQuery);
  const manualClearCount = useUiStore((state) => state.manualClearCount);
  const isSidebarCollapsed = useUiStore((state) => state.isSidebarCollapsed);
  const isSearchExpanded = useUiStore((state) => state.isSearchExpanded);

  const setActiveView = useUiStore((state) => state.setActiveView);
  const setSelectedFolderId = useUiStore((state) => state.setSelectedFolderId);
  const setSelectedNoteId = useUiStore((state) => state.setSelectedNoteId);
  const setSearchQuery = useUiStore((state) => state.setSearchQuery);
  const setIsSearchExpanded = useUiStore((state) => state.setIsSearchExpanded);
  const clearSelectedNote = useUiStore((state) => state.clearSelectedNote);
  const toggleSidebarCollapsed = useUiStore((state) => state.toggleSidebarCollapsed);

  return {
    activeView,
    selectedFolderId,
    selectedNoteId,
    searchQuery,
    isSearchExpanded,
    manualClearCount,
    isSidebarCollapsed,
    setActiveView,
    setSelectedFolderId,
    setSelectedNoteId,
    setSearchQuery,
    setIsSearchExpanded,
    clearSelectedNote,
    toggleSidebarCollapsed,
  };
}
