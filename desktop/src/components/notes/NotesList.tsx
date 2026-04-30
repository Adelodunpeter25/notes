import { useEffect, useState, type MouseEvent } from "react";
import { FileText, PanelLeft, Pin, SquarePen, Folder as FolderIcon } from "lucide-react";

import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import { ConfirmDialog, Skeleton } from "@/components/common";
import { formatNoteDate } from "@shared-utils/formatDate";
import { EditorPreview } from "@/components/editor";
import { invoke } from "@tauri-apps/api/core";
import { showNoteContextMenu } from "@/services";

type NotesListProps = {
  notes: Note[];
  folders: Folder[];
  selectedNoteId?: string;
  selectedFolderName?: string;
  isSidebarCollapsed?: boolean;
  isLoading?: boolean;
  isDeleting?: boolean;
  onSelectNote: (noteId: string) => void;
  onCreateNote: () => void;
  onUpdateNote: (noteId: string, payload: { isPinned?: boolean; folderId?: string }) => Promise<unknown> | void;
  onDeleteNote: (noteId: string) => Promise<unknown> | void;
  onToggleSidebar: () => void;
};

export function NotesList({
  notes,
  folders,
  selectedNoteId,
  selectedFolderName,
  isSidebarCollapsed = false,
  isLoading = false,
  isDeleting = false,
  onSelectNote,
  onCreateNote,
  onUpdateNote,
  onDeleteNote,
  onToggleSidebar,
}: NotesListProps) {
  const [deleteTargetNoteId, setDeleteTargetNoteId] = useState<string | null>(null);

  async function handleContextMenu(event: MouseEvent, noteId: string) {
    event.preventDefault();
    const note = notes.find((item) => item.id === noteId);
    if (!note) {
      return;
    }

    await showNoteContextMenu({
      x: event.clientX,
      y: event.clientY,
      isPinned: note.isPinned,
      folders,
      currentFolderId: note.folderId,
      onPinToggle: () => {
        void onUpdateNote(note.id, { isPinned: !note.isPinned });
      },
      onMoveTo: (folderId) => {
        void onUpdateNote(note.id, { folderId: folderId ?? undefined });
      },
      onOpenInQuickNote: () => {
        void invoke("open_in_quick_note", { noteId: note.id });
      },
      onDelete: () => {
        setDeleteTargetNoteId(note.id);
      },
    });
  }

  useEffect(() => {
    function handleEscapeKey(event: KeyboardEvent) {
      if (event.key !== "Escape") {
        return;
      }

      setDeleteTargetNoteId(null);
    }

    if (!deleteTargetNoteId) {
      return;
    }

    window.addEventListener("keydown", handleEscapeKey);
    return () => {
      window.removeEventListener("keydown", handleEscapeKey);
    };
  }, [deleteTargetNoteId]);

  return (
    <>
      <ConfirmDialog
        open={Boolean(deleteTargetNoteId)}
        title="Move to Trash?"
        description="This note will be moved to trash. You can restore it or delete it permanently from there."
        confirmLabel="Move to Trash"
        onCancel={() => setDeleteTargetNoteId(null)}
        onConfirm={async () => {
          if (!deleteTargetNoteId) {
            return;
          }

          await onDeleteNote(deleteTargetNoteId);
          setDeleteTargetNoteId(null);
        }}
        loading={isDeleting}
        destructive
      />

      <div className="flex h-full flex-col bg-background border-r border-border">
        {/* Top Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-border/50">
          <div className="flex items-center gap-3 text-muted">
            <p className="text-sm font-semibold text-text">{selectedFolderName || "All Notes"}</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={onToggleSidebar}
              className="text-muted hover:text-text transition-[color,transform] duration-140 ease-out active:scale-95"
              title={isSidebarCollapsed ? "Show sidebar" : "Hide sidebar"}
            >
              <PanelLeft
                size={18}
                className={isSidebarCollapsed ? "opacity-80" : "opacity-100"}
              />
            </button>
            <button
              onClick={onCreateNote}
              className="text-muted hover:text-text transition-[color,transform] duration-140 ease-out active:scale-95"
              title="New note"
            >
              <SquarePen size={18} />
            </button>
          </div>
        </div>


        {/* Note List Container */}
        <div className="flex-1 overflow-y-auto w-full p-2">
          {isLoading ? (
            <div className="space-y-4 p-2">
              <Skeleton className="h-16 w-full rounded-md" />
              <Skeleton className="h-16 w-full rounded-md" />
              <Skeleton className="h-16 w-full rounded-md" />
            </div>
          ) : notes.length === 0 ? (
            <div className="px-3 py-6 text-center">
              <div className="mx-auto mb-2 flex size-8 items-center justify-center rounded-full text-muted">
                <FileText size={16} />
              </div>
              <p className="text-sm font-medium text-muted">No notes yet</p>
              <p className="mt-1 text-xs text-muted/80">Create your first note in this view.</p>
            </div>
          ) : (
            <div className="flex flex-col gap-[2px]">
              {notes.map((note) => {
                const active = selectedNoteId === note.id;
                const title = note.title?.trim() || "Untitled";
                const displayDate = formatNoteDate(note.updatedAt || note.createdAt);
                const isAllNotesView = (selectedFolderName || "All Notes") === "All Notes";
                const folderName =
                  isAllNotesView && note.folderId
                    ? folders.find((folder) => folder.id === note.folderId)?.name
                    : null;

                return (
                  <button
                    key={note.id}
                    onClick={() => onSelectNote(note.id)}
                    onMouseDown={(event) => {
                      if (event.button === 2) {
                        event.preventDefault();
                      }
                    }}
                    onContextMenu={(e) => handleContextMenu(e, note.id)}
                    className={[
                      "relative flex w-full select-none flex-col items-start gap-1 rounded-lg p-3 pr-8 text-left transition-[background-color,transform] duration-140 ease-out active:scale-[0.995]",
                      active ? "bg-white/10" : "hover:bg-white/5",
                    ].join(" ")}
                  >
                    {note.isPinned ? (
                      <span className="absolute right-3 top-3 text-accent" aria-label="Pinned note" title="Pinned">
                        <Pin size={14} />
                      </span>
                    ) : null}
                    
                    {/* Title Row */}
                    <span className="text-[14.5px] font-bold text-white truncate w-full mb-0.5 leading-tight">
                      {title}
                    </span>

                    {/* Meta Row: Time & Preview */}
                    <div className="flex items-center gap-2 text-[13px] w-full truncate leading-tight">
                      <span className="text-white font-semibold shrink-0">
                        {displayDate}
                      </span>
                      <EditorPreview content={note.content} maxLength={40} />
                    </div>

                    {/* Folder Row - only show in All Notes view and if the note has a folder */}
                    {folderName ? (
                      <div className="flex items-center gap-1.5 text-[11px] text-accent mt-1.5 font-bold">
                        <FolderIcon size={12} strokeWidth={2.5} />
                        <span className="truncate max-w-[180px]">
                          {folderName}
                        </span>
                      </div>
                    ) : null}
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
