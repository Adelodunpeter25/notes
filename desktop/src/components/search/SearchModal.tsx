import { useEffect, useRef, useState } from "react";
import { Search, FileText, X } from "lucide-react";
import { useUiStore } from "@/stores";
import { useNotesQuery, useDebounce } from "@/hooks";
import { formatNoteDate } from "@shared-utils/formatDate";
import { EditorPreview } from "@/components/editor";

export function SearchModal() {
  const isOpen = useUiStore((state) => state.isSearchModalOpen);
  const setIsOpen = useUiStore((state) => state.setIsSearchModalOpen);
  const navigateToNote = useUiStore((state) => state.navigateToNote);
  
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);
  const inputRef = useRef<HTMLInputElement>(null);
  const [selectedIndex, setSelectedIndex] = useState(0);

  // Load results - if query is empty, it reflects all notes per user request
  const { data: notes = [], isLoading } = useNotesQuery({ 
    q: debouncedQuery.trim() || undefined
  });

  // Reset selected index when results change
  useEffect(() => {
    setSelectedIndex(0);
  }, [notes]);

  // Handle focus and reset
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 10);
      setQuery("");
    }
  }, [isOpen]);

  // Handle keyboard navigation
  useEffect(() => {
    if (!isOpen) return;

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        setIsOpen(false);
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex((prev) => (prev + 1) % Math.max(1, notes.length));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex((prev) => (prev - 1 + notes.length) % Math.max(1, notes.length));
      } else if (e.key === "Enter" && notes.length > 0) {
        e.preventDefault();
        const note = notes[selectedIndex];
        handleSelect(note.id, note.folderId || null);
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isOpen, notes, selectedIndex, setIsOpen]);

  function handleSelect(noteId: string, folderId: string | null) {
    navigateToNote(noteId, folderId);
    setIsOpen(false);
  }

  if (!isOpen) return null;

  return (
    <div 
      className="fixed inset-0 z-[100] flex items-start justify-center pt-[15vh] px-4 pointer-events-none"
    >
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-sm pointer-events-auto"
        onClick={() => setIsOpen(false)}
      />

      {/* Modal Content */}
      <div 
        className="relative w-full max-w-2xl bg-[#1E1E1E] border border-white/10 rounded-xl shadow-2xl overflow-hidden pointer-events-auto flex flex-col"
      >
        {/* Search Bar */}
        <div className="flex items-center px-4 py-4 border-b border-white/5 gap-3">
          <Search size={20} className="text-muted shrink-0" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search notes..."
            className="flex-1 bg-transparent border-none outline-none text-text text-sm placeholder:text-muted/50"
          />
          {query && (
            <button 
              onClick={() => setQuery("")}
              className="p-1 hover:bg-white/5 rounded-md text-muted"
            >
              <X size={16} />
            </button>
          )}
          <div className="px-2 py-1 bg-white/5 border border-white/10 rounded text-[9.5px] text-muted font-bold uppercase tracking-wider">
            ESC to close
          </div>
        </div>

        {/* Results */}
        <div className="flex-1 overflow-y-auto max-h-[400px] p-2 custom-scrollbar">
          {isLoading ? (
            <div className="p-4 text-center text-muted text-sm italic">Searching...</div>
          ) : notes.length === 0 ? (
            <div className="p-12 text-center text-muted">
              <div className="mx-auto mb-3 flex size-10 items-center justify-center rounded-full bg-danger/10 text-danger/60">
                <X size={20} />
              </div>
              <p className="font-medium text-sm">No results found for "{query}"</p>
            </div>
          ) : (
            <div className="space-y-0.5">
              {notes.map((note, index) => (
                <button
                  key={note.id}
                  onClick={() => handleSelect(note.id, note.folderId || null)}
                  onMouseEnter={() => setSelectedIndex(index)}
                  className={`
                    w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left transition-colors
                    ${index === selectedIndex ? "bg-accent/10 border border-accent/20" : "hover:bg-white/5 border border-transparent"}
                  `}
                >
                  <div className={`p-1.5 rounded-md ${index === selectedIndex ? "bg-accent/20 text-accent" : "bg-white/5 text-muted"}`}>
                    <FileText size={14} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-bold text-[12.5px] text-text truncate">
                        {note.title || "Untitled"}
                      </span>
                      <span className="text-[10px] text-muted shrink-0">
                        {formatNoteDate(note.updatedAt || note.createdAt)}
                      </span>
                    </div>
                    <div className="text-[11px] text-muted/80 truncate mt-0.5">
                      <EditorPreview content={note.content} maxLength={80} />
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-4 py-3 border-t border-white/5 flex items-center justify-between text-[11px] text-muted font-medium bg-black/10">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-1.5">
              <span className="px-1.5 py-0.5 bg-white/5 border border-white/10 rounded text-[10px]">↵</span>
              <span>to select</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="px-1.5 py-0.5 bg-white/5 border border-white/10 rounded text-[10px]">↑↓</span>
              <span>to navigate</span>
            </div>
          </div>
          <div>{notes.length} results</div>
        </div>
      </div>
    </div>
  );
}
