import { useUiStore } from "@/stores";

export function useDashboardSelection() {
  const selectedFolderId = useUiStore((state) => state.selectedFolderId);
  const selectedNoteId = useUiStore((state) => state.selectedNoteId);
  const searchQuery = useUiStore((state) => state.searchQuery);
  const manualClearCount = useUiStore((state) => state.manualClearCount);
  const isSidebarCollapsed = useUiStore((state) => state.isSidebarCollapsed);
  const isSearchExpanded = useUiStore((state) => state.isSearchExpanded);

  const setSelectedFolderId = useUiStore((state) => state.setSelectedFolderId);
  const setSelectedNoteId = useUiStore((state) => state.setSelectedNoteId);
  const setSearchQuery = useUiStore((state) => state.setSearchQuery);
  const setIsSearchExpanded = useUiStore((state) => state.setIsSearchExpanded);
  const clearSelectedNote = useUiStore((state) => state.clearSelectedNote);
  const toggleSidebarCollapsed = useUiStore((state) => state.toggleSidebarCollapsed);

  return {
    selectedFolderId,
    selectedNoteId,
    searchQuery,
    isSearchExpanded,
    manualClearCount,
    isSidebarCollapsed,
    setSelectedFolderId,
    setSelectedNoteId,
    setSearchQuery,
    setIsSearchExpanded,
    clearSelectedNote,
    toggleSidebarCollapsed,
  };
}
