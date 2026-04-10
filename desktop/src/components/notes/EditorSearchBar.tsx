import { ChevronDown, ChevronUp, X } from "lucide-react";
import { useEditorSearch } from "@/hooks/useEditorSearch";

export function EditorSearchBar() {
  const { isOpen, setIsOpen, query, setQuery, inputRef, findNext, findPrev } = useEditorSearch();

  if (!isOpen) return null;

  return (
    <div className="flex items-center gap-1 border-b border-border bg-surface px-3 py-1.5">
      <input
        ref={inputRef}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Find in note..."
        className="flex-1 bg-transparent text-[13px] text-text outline-none placeholder:text-muted/50"
      />
      <span className="text-[11px] text-muted px-1">Enter to find</span>
      <button onClick={findPrev} className="p-1 rounded hover:bg-white/10 text-muted hover:text-text">
        <ChevronUp size={14} />
      </button>
      <button onClick={findNext} className="p-1 rounded hover:bg-white/10 text-muted hover:text-text">
        <ChevronDown size={14} />
      </button>
      <button onClick={() => setIsOpen(false)} className="p-1 rounded hover:bg-white/10 text-muted hover:text-text">
        <X size={14} />
      </button>
    </div>
  );
}
