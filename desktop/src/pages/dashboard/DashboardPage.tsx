import { useEffect, useRef } from "react";
import { CheckCircle } from "lucide-react";

import { NoteEditor, NotesList, FoldersSidebar } from "@/components/notes";
import { TasksList } from "@/components/tasks/TasksList";
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
          leftCollapsed={selection.isSidebarCollapsed || isSearchActive || selection.activeView === "tasks"}
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
            ) : selection.activeView === "tasks" ? (
              <TasksList
                tasks={data.tasks}
                isLoading={data.isTasksLoading}
                onCreateTask={data.createTask}
                onUpdateTask={data.updateTask}
                onDeleteTask={data.deleteTask}
                onToggleTask={data.toggleTask}
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
            selection.activeView === "tasks" ? (
              <div className="flex h-full items-center justify-center p-8 text-center bg-[#1e1e1e]">
                <div className="space-y-4 max-w-sm">
                  <div className="mx-auto w-16 h-16 rounded-full bg-accent/10 flex items-center justify-center">
                    <CheckCircle className="text-accent" size={32} />
                  </div>
                  <div>
                    <h3 className="text-lg font-medium text-text">Task Details</h3>
                    <p className="mt-2 text-sm text-muted">Select a task to view more details and add notes or deadlines. (Coming soon)</p>
                  </div>
                </div>
              </div>
            ) : (
              <NoteEditor
                note={data.selectedNote}
                onSave={data.saveNote}
                onLocalSave={data.saveNoteLocal}
                onClearSelection={selection.clearSelectedNote}
              />
            )
          }
        />
      </div>
    </main>
  );
}
