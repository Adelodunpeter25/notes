import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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

  const find = useCallback((reverse = false) => {
    if (!query) return;
    const editorEl = document.querySelector(".ProseMirror");
    if (editorEl) {
      const text = editorEl.textContent ?? "";
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      setMatchCount((text.match(new RegExp(escaped, "gi")) ?? []).length);
    }
    window.find(query, false, reverse, true, false, false, false);
  }, [query]);

  useEffect(() => {
    if (!isOpen) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") { e.stopPropagation(); setIsOpen(false); }
      if (e.key === "Enter") { e.preventDefault(); find(e.shiftKey); }
    }
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [isOpen, find, setIsOpen]);

  const findNext = useCallback(() => find(false), [find]);
  const findPrev = useCallback(() => find(true), [find]);

  return useMemo(() => ({
    isOpen,
    setIsOpen,
    query,
    setQuery,
    matchCount,
    inputRef,
    findNext,
    findPrev,
  }), [isOpen, setIsOpen, query, matchCount, findNext, findPrev]);
}
