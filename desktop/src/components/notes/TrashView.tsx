import { useState } from "react";
import { Trash2 } from "lucide-react";

import { formatNoteDate } from "@shared-utils/formatDate";
import { ConfirmDialog, EmptyState, Skeleton } from "@/components/common";
import { NoteEditor } from "@/components/notes/NoteEditor";
import { useTrashQuery, useRestoreNoteMutation, usePermanentlyDeleteNoteMutation, useClearTrashMutation } from "@/hooks";

export function TrashNoteList({
  selectedNoteId,
  onSelectNote,
}: {
  selectedNoteId?: string;
  onSelectNote: (id: string) => void;
}) {
  const [confirmClear, setConfirmClear] = useState(false);
  const { data: trashedNotes = [], isLoading } = useTrashQuery();
  const clearTrashMutation = useClearTrashMutation();

  return (
    <>
      <div className="flex h-full flex-col bg-[#1e1e1e]">
        <div className="flex items-center justify-between px-4 py-3 border-b border-border shrink-0">
          <div className="flex items-center gap-2 text-text">
            <Trash2 size={15} strokeWidth={1.5} />
            <span className="text-[13px] font-semibold tracking-wide">Trash</span>
          </div>
          {trashedNotes.length > 0 && (
            <button
              onClick={() => setConfirmClear(true)}
              className="text-[12px] text-red-400 hover:text-red-300 transition-colors"
            >
              Empty
            </button>
          )}
        </div>

        <div className="flex-1 overflow-y-auto scrollbar-none">
          {isLoading ? (
            <div className="p-3 space-y-2">
              {[1, 2, 3].map((i) => (
                <Skeleton key={i} className="h-14 w-full rounded-md bg-white/5" />
              ))}
            </div>
          ) : trashedNotes.length === 0 ? (
            <EmptyState variant="simple" title="Trash is empty" />
          ) : (
            trashedNotes.map((note) => (
              <div
                key={note.id}
                onClick={() => onSelectNote(note.id)}
                className={[
                  "px-4 py-3 cursor-pointer border-b border-border/50 transition-colors select-none",
                  selectedNoteId === note.id ? "bg-white/10" : "hover:bg-white/5",
                ].join(" ")}
              >
                <p className="text-[13px] font-medium text-text truncate">{note.title || "Untitled"}</p>
                <p className="text-[11px] text-muted mt-0.5">{formatNoteDate(note.deletedAt)}</p>
              </div>
            ))
          )}
        </div>
      </div>

      <ConfirmDialog
        open={confirmClear}
        title="Empty Trash?"
        description="All notes in trash will be permanently deleted. This cannot be undone."
        confirmLabel="Empty Trash"
        destructive
        onConfirm={() => {
          clearTrashMutation.mutate();
          setConfirmClear(false);
        }}
        onCancel={() => setConfirmClear(false)}
      />
    </>
  );
}

export function TrashEditor({ selectedNoteId, onClear }: { selectedNoteId?: string; onClear: () => void }) {
  const { data: trashedNotes = [] } = useTrashQuery();
  const restoreMutation = useRestoreNoteMutation();
  const permanentDeleteMutation = usePermanentlyDeleteNoteMutation();

  const selectedNote = trashedNotes.find((n) => n.id === selectedNoteId);

  if (!selectedNote) {
    return (
      <div className="flex h-full items-center justify-center bg-background">
        <EmptyState variant="simple" title="Select a note to preview" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col bg-background">
      <div className="flex items-center gap-3 px-4 py-2 border-b border-border shrink-0">
        <button
          onClick={() => restoreMutation.mutate(selectedNote.id, { onSuccess: onClear })}
          className="text-[12px] text-accent hover:text-accent/80 transition-colors"
        >
          Restore
        </button>
        <span className="text-muted text-[12px]">·</span>
        <button
          onClick={() => permanentDeleteMutation.mutate(selectedNote.id, { onSuccess: onClear })}
          className="text-[12px] text-red-400 hover:text-red-300 transition-colors"
        >
          Delete Forever
        </button>
      </div>
      <NoteEditor
        note={selectedNote}
        onSave={() => {}}
        onClearSelection={onClear}
      />
    </div>
  );
}
