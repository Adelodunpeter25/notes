import { useEffect, useState, type MouseEvent } from "react";
import { Folder, PlusCircle } from "lucide-react";

import type { Folder as FolderType } from "@shared/folders";
import { SidebarItem, Skeleton, ConfirmDialog } from "@/components/common";
import { showFolderContextMenu } from "@/services";

type FoldersSidebarProps = {
  folders: FolderType[];
  selectedFolderId: string | null;
  isLoading?: boolean;
  onSelectFolder: (folderId: string | null) => void;
  onCreateFolder: () => void;
  editingFolderId?: string | null;
  onRenameFolder?: (folderId: string, newName: string) => void;
  setEditingFolderId?: (folderId: string | null) => void;
  onDeleteFolder?: (folderId: string) => void;
};

export function FoldersSidebar({
  folders,
  selectedFolderId,
  isLoading = false,
  onSelectFolder,
  onCreateFolder,
  editingFolderId,
  onRenameFolder,
  setEditingFolderId,
  onDeleteFolder,
}: FoldersSidebarProps) {
  const [editingName, setEditingName] = useState("");
  const [deleteTargetFolderId, setDeleteTargetFolderId] = useState<string | null>(null);

  useEffect(() => {
    if (editingFolderId) {
      const folder = folders.find((f) => f.id === editingFolderId);
      setEditingName(folder?.name || "");
    } else {
      setEditingName("");
    }
  }, [editingFolderId, folders]);

  useEffect(() => {
    function handleEscapeKey(event: KeyboardEvent) {
      if (event.key !== "Escape") {
        return;
      }
      setDeleteTargetFolderId(null);
    }

    if (deleteTargetFolderId) {
      window.addEventListener("keydown", handleEscapeKey);
    }
    return () => {
      window.removeEventListener("keydown", handleEscapeKey);
    };
  }, [deleteTargetFolderId]);

  async function handleContextMenu(event: MouseEvent, folderId: string) {
    event.preventDefault();
    await showFolderContextMenu({
      x: event.clientX,
      y: event.clientY,
      onRename: () => setEditingFolderId?.(folderId),
      onDelete: () => setDeleteTargetFolderId(folderId),
    });
  }

  async function handleConfirmDelete() {
    if (deleteTargetFolderId && onDeleteFolder) {
      onDeleteFolder(deleteTargetFolderId);
      setDeleteTargetFolderId(null);
    }
  }

  return (
    <>
      <div className="flex h-full flex-col bg-[#2b2b2b] border-r border-border py-2 px-2 relative">
        {isLoading ? (
          <div className="space-y-4 px-2 mt-4">
            <Skeleton className="h-10 w-full rounded-md bg-white/5" />
            <Skeleton className="h-10 w-full rounded-md bg-white/5" />
            <Skeleton className="h-10 w-full rounded-md bg-white/5" />
          </div>
        ) : (
          <div className="space-y-0.5 overflow-y-auto mt-2">
            <SidebarItem
              icon={<Folder size={16} strokeWidth={2} />}
              active={selectedFolderId === null}
              onClick={() => onSelectFolder(null)}
            >
              All Notes
            </SidebarItem>

            {folders.map((folder) => (
              <div
                key={folder.id}
                onContextMenu={(e) => handleContextMenu(e, folder.id)}
              >
                <SidebarItem
                  icon={<Folder size={16} strokeWidth={2} />}
                  active={selectedFolderId === folder.id}
                  count={folder.notesCount}
                  onClick={() => onSelectFolder(folder.id)}
                  onDoubleClick={() => setEditingFolderId?.(folder.id)}
                  isEditing={editingFolderId === folder.id}
                  editValue={editingName}
                  onEditChange={setEditingName}
                  onEditSubmit={() => {
                    if (editingName !== folder.name) {
                      onRenameFolder?.(folder.id, editingName);
                    } else {
                      setEditingFolderId?.(null);
                    }
                  }}
                  onEditCancel={() => setEditingFolderId?.(null)}
                >
                  {folder.name}
                </SidebarItem>
              </div>
            ))}
          </div>
        )}

        {!isLoading && folders.length === 0 ? (
          <div className="mt-6 px-2">
            <p className="text-sm font-medium text-muted">No folders yet</p>
            <p className="mt-1 text-xs text-muted/80">Create a folder to organize your notes.</p>
          </div>
        ) : null}

        <div className="mt-auto pt-4 pb-4 px-2 flex items-center justify-start">
          <button
            onClick={onCreateFolder}
            className="flex items-center gap-2 text-[#9a9a9a] hover:text-[#e3e3e3] py-1 transition-colors group outline-none"
          >
            <PlusCircle size={22} strokeWidth={1.5} />
            <span className="text-[14px] font-medium tracking-wide">New Folder</span>
          </button>
        </div>
      </div>
      <ConfirmDialog
        open={deleteTargetFolderId !== null}
        title="Delete Folder?"
        description="Are you sure you want to delete this folder? All notes inside will be moved to 'All Notes'."
        confirmLabel="Delete"
        destructive
        onConfirm={handleConfirmDelete}
        onCancel={() => setDeleteTargetFolderId(null)}
      />
    </>
  );
}
