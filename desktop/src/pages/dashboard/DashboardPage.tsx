import { useEffect } from "react";

import { NoteEditor, NotesList, FoldersSidebar } from "@/components/notes";
import { ResizableLayout } from "@/components/common";
import { SearchResultsPage } from "./SearchResultsPage";
import {
  useDashboardData,
  useDashboardSelection,
} from "@/hooks";
import { useKeyboardShortcutsStore } from "@/stores";

export function DashboardPage() {
  const selection = useDashboardSelection();
  const data = useDashboardData(selection);
  const setNewNoteHandler = useKeyboardShortcutsStore((state) => state.setNewNoteHandler);

  useEffect(() => {
    setNewNoteHandler(() => {
      void data.createNote();
    });

    return () => {
      setNewNoteHandler(null);
    };
  }, [data.createNote, setNewNoteHandler]);

  return (
    <main className="flex min-h-0 flex-1 flex-col bg-background">
      <div className="min-h-0 flex-1">
        <ResizableLayout
          leftCollapsed={selection.isSidebarCollapsed}
          left={
            <FoldersSidebar
              folders={data.folders}
              selectedFolderId={selection.selectedFolderId}
              isLoading={data.isFoldersLoading}
              onSelectFolder={selection.setSelectedFolderId}
              onCreateFolder={data.createFolder}
              editingFolderId={data.editingFolderId}
              onRenameFolder={data.renameFolder}
              setEditingFolderId={data.setEditingFolderId}
              onDeleteFolder={data.deleteFolder}
            />
          }
          center={
            !(selection.isSearchExpanded && selection.searchQuery.length > 0) ? (
              <NotesList
                notes={data.notes}
                folders={data.folders}
                selectedNoteId={selection.selectedNoteId}
                selectedFolderName={data.selectedFolderName}
                isSidebarCollapsed={selection.isSidebarCollapsed}
                isLoading={data.isNotesLoading}
                isDeleting={data.isDeleting}
                onSelectNote={selection.setSelectedNoteId}
                onCreateNote={data.createNote}
                onUpdateNote={data.updateNote}
                onDeleteNote={data.deleteNote}
                onToggleSidebar={selection.toggleSidebarCollapsed}
              />
            ) : null
          }
          right={
            <NoteEditor
              note={data.selectedNote}
              onSave={data.saveNote}
              onClearSelection={selection.clearSelectedNote}
              searchResultsOverlay={
                selection.isSearchExpanded && selection.searchQuery.length > 0 ? (
                  <SearchResultsPage
                    notes={data.notes}
                    searchQuery={selection.searchQuery}
                    selectedNoteId={selection.selectedNoteId}
                    onSelectNote={(noteId) => {
                      selection.setSelectedNoteId(noteId);
                      selection.setIsSearchExpanded(false);
                      selection.setSearchQuery('');
                    }}
                  />
                ) : undefined
              }
            />
          }
        />
      </div>
    </main>
  );
}
