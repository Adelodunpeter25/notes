import { useEffect, useRef, useState } from "react";
import { NoteEditor, NotesList, FoldersSidebar, TrashNoteList, TrashEditor } from "@/components/notes";
import { TasksList } from "@/components/tasks/TasksList";
import { ResizableLayout } from "@/components/common";
import {
  useDashboardData,
  useDashboardSelection,
} from "@/hooks";
import { useKeyboardShortcutsStore, useUiStore } from "@/stores";

export function DashboardPage() {
  const selection = useDashboardSelection();
  const data = useDashboardData(selection);
  const setNewNoteHandler = useKeyboardShortcutsStore((state) => state.setNewNoteHandler);
  const setNewFolderHandler = useKeyboardShortcutsStore((state) => state.setNewFolderHandler);
  const setActiveView = useUiStore((state) => state.setActiveView);
  const [trashSelectedNoteId, setTrashSelectedNoteId] = useState<string | undefined>();
  const createNoteRef = useRef(data.createNote);
  const createFolderRef = useRef(data.createFolder);

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

  const isTrash = selection.activeView === "trash";

  if (selection.activeView === "tasks") {
    return (
      <main className="flex h-full flex-1 flex-col bg-background">
        <TasksList
          tasks={data.tasks}
          isLoading={data.isTasksLoading}
          onCreateTask={data.createTask}
          onUpdateTask={data.updateTask}
          onDeleteTask={data.deleteTask}
          onToggleTask={data.toggleTask}
        />
      </main>
    );
  }

  return (
    <main className="flex min-h-0 flex-1 flex-col bg-background">
      <div className="min-h-0 flex-1">
        <ResizableLayout
          leftCollapsed={selection.isSidebarCollapsed}
          left={
            <FoldersSidebar
              folders={data.folders}
              selectedFolderId={selection.selectedFolderId}
              activeView={selection.activeView}
              isLoading={data.isFoldersLoading}
              onSelectFolder={selection.setSelectedFolderId}
              onCreateFolder={data.createFolder}
              onSelectTrash={() => setActiveView("trash")}
              editingFolderId={data.editingFolderId}
              onRenameFolder={data.renameFolder}
              setEditingFolderId={data.setEditingFolderId}
              onDeleteFolder={data.deleteFolder}
            />
          }
          center={
            isTrash ? (
              <TrashNoteList
                selectedNoteId={trashSelectedNoteId}
                onSelectNote={setTrashSelectedNoteId}
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
            isTrash ? (
              <TrashEditor
                selectedNoteId={trashSelectedNoteId}
                onClear={() => setTrashSelectedNoteId(undefined)}
              />
            ) : (
              <NoteEditor
                note={data.selectedNote}
                onSave={data.saveNote}
                onClearSelection={selection.clearSelectedNote}
              />
            )
          }
        />
      </div>
    </main>
  );
}
