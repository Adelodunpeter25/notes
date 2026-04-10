import { useEffect, useRef, useState } from "react";
import { useUiStore } from "@/stores";

export function useEditorSearch() {
  const isOpen = useUiStore((state) => state.isEditorSearchOpen);
  const setIsOpen = useUiStore((state) => state.setIsEditorSearchOpen);
  const [query, setQuery] = useState("");
  const [matchCount, setMatchCount] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 10);
    } else {
      setQuery("");
      setMatchCount(0);
      window.getSelection()?.removeAllRanges();
    }
  }, [isOpen]);

  // Real-time search + count on query change
  useEffect(() => {
    if (!query) {
      setMatchCount(0);
      window.getSelection()?.removeAllRanges();
      return;
    }

    // Count matches in the editor DOM
    const editorEl = document.querySelector(".ProseMirror");
    if (editorEl) {
      const text = editorEl.textContent ?? "";
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const count = (text.match(new RegExp(escaped, "gi")) ?? []).length;
      setMatchCount(count);
    }

    // Jump to first match
    window.find(query, false, false, true, false, false, false);
  }, [query]);

  useEffect(() => {
    if (!isOpen) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") { e.stopPropagation(); setIsOpen(false); }
      if (e.key === "Enter") { e.preventDefault(); find(e.shiftKey); }
    }
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [isOpen, query]);

  function find(reverse = false) {
    if (!query) return;
    window.find(query, false, reverse, true, false, false, false);
  }

  return {
    isOpen,
    setIsOpen,
    query,
    setQuery,
    matchCount,
    inputRef,
    findNext: () => find(false),
    findPrev: () => find(true),
  };
}
