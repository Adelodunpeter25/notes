import { useEffect, useRef } from "react";

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
  const setNewFolderHandler = useKeyboardShortcutsStore((state) => state.setNewFolderHandler);
  const createNoteRef = useRef(data.createNote);
  const createFolderRef = useRef(data.createFolder);

  const isSearchActive = selection.isSearchExpanded && selection.searchQuery.trim().length > 0;

  useEffect(() => {
    createNoteRef.current = data.createNote;
  }, [data.createNote]);

  useEffect(() => {
    createFolderRef.current = data.createFolder;
  }, [data.createFolder]);

  useEffect(() => {
    setNewNoteHandler(() => {
      void createNoteRef.current();
    });

    return () => {
      setNewNoteHandler(null);
    };
  }, [setNewNoteHandler]);

  useEffect(() => {
    setNewFolderHandler(() => {
      void createFolderRef.current();
    });

    return () => {
      setNewFolderHandler(null);
    };
  }, [setNewFolderHandler]);

  return (
    <main className="flex min-h-0 flex-1 flex-col bg-background">
      <div className="min-h-0 flex-1">
        <ResizableLayout
          leftCollapsed={selection.isSidebarCollapsed || isSearchActive}
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
            isSearchActive ? (
              <SearchResultsPage
                notes={data.notes}
                searchQuery={selection.searchQuery}
                selectedNoteId={selection.selectedNoteId}
                onSelectNote={(noteId) => {
                  selection.setSelectedNoteId(noteId);
                }}
              />
            ) : (
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
            )
          }
          right={
            <NoteEditor
              note={data.selectedNote}
              onSave={data.saveNote}
              onLocalSave={data.saveNoteLocal}
              onClearSelection={selection.clearSelectedNote}
            />
          }
        />
      </div>
    </main>
  );
}
