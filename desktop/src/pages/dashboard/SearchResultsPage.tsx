import { Search } from "lucide-react";
import type { Note } from "@shared/notes";
import { formatNoteDate } from "@/utils/formatDate";
import { EditorPreview } from "@/components/editor";

type SearchResultsPageProps = {
    notes: Note[];
    searchQuery: string;
    selectedNoteId?: string;
    onSelectNote: (noteId: string) => void;
};

export function SearchResultsPage({
    notes,
    searchQuery,
    selectedNoteId,
    onSelectNote,
}: SearchResultsPageProps) {
    return (
        <div className="flex h-full flex-col bg-background animate-in fade-in duration-200">
            <div className="flex items-center px-4 py-3 border-b border-border/50 shrink-0 h-[48px]">
                <Search size={16} className="text-muted mr-3" />
                <h2 className="text-sm font-semibold text-text truncate">
                    {searchQuery ? `Top Hits for "${searchQuery}"` : "Search Notes"}
                </h2>
            </div>

            <div className="flex-1 overflow-y-auto w-full p-2">
                {notes.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-full text-center p-4">
                        <div className="flex size-12 items-center justify-center rounded-full bg-surface mb-3">
                            <Search size={20} className="text-muted" />
                        </div>
                        <p className="text-base font-semibold text-text mb-1">No Results Found</p>
                        <p className="text-sm text-muted">
                            {searchQuery ? `No notes matching "${searchQuery}"` : "Type in the search bar to find notes."}
                        </p>
                    </div>
                ) : (
                    <div className="flex flex-col gap-[2px]">
                        <p className="text-xs font-semibold text-muted px-3 py-2 uppercase tracking-wider">
                            {notes.length} {notes.length === 1 ? 'Note' : 'Notes'} Found
                        </p>
                        {notes.map((note) => {
                            const active = selectedNoteId === note.id;
                            const title = note.title?.trim() || "Untitled";
                            const displayDate = formatNoteDate(note.updatedAt || note.createdAt);

                            return (
                                <button
                                    key={note.id}
                                    onClick={() => onSelectNote(note.id)}
                                    className={[
                                        "relative flex flex-col items-start gap-1 p-3 text-left w-full rounded-lg transition-colors select-none",
                                        active ? "bg-[#333333]" : "hover:bg-white/5",
                                    ].join(" ")}
                                >
                                    <span className="text-sm font-bold text-text truncate w-full">
                                        {title}
                                    </span>
                                    <div className="flex items-center text-xs text-muted w-full truncate gap-2 font-medium">
                                        <span className="shrink-0">{displayDate}</span>
                                        <EditorPreview content={note.content} />
                                    </div>
                                </button>
                            );
                        })}
                    </div>
                )}
            </div>
        </div>
    );
}
