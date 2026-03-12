import { Search } from "lucide-react";
import type { Note } from "@shared/notes";
import { formatNoteDate } from "@/utils/formatDate";

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
    const normalizedQuery = searchQuery.trim();

    function highlightText(text: string): React.ReactNode {
        if (!normalizedQuery) {
            return text;
        }
        const escaped = normalizedQuery.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const parts = text.split(new RegExp(`(${escaped})`, "gi"));
        return parts.map((part, index) =>
            part.toLowerCase() === normalizedQuery.toLowerCase() ? (
                <span key={index} className="text-accent bg-accent/20">
                    {part}
                </span>
            ) : (
                <span key={index}>{part}</span>
            ),
        );
    }

    function previewFromHtml(html: string): string {
        if (!html) return "";
        const doc = new DOMParser().parseFromString(html, "text/html");
        const text = (doc.body.textContent || "").replace(/\u00a0/g, " ").trim();
        return text;
    }

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
                            const preview = previewFromHtml(note.content || "");

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
                                        {highlightText(title)}
                                    </span>
                                    <div className="flex items-center text-xs text-muted w-full truncate gap-2 font-medium">
                                        <span className="shrink-0">{displayDate}</span>
                                        <span className="truncate">
                                            {highlightText(preview)}
                                        </span>
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
