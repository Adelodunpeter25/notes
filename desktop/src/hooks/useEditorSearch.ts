import { useEffect, useRef, useState } from "react";
import { useUiStore } from "@/stores";

export function useEditorSearch() {
  const isOpen = useUiStore((state) => state.isEditorSearchOpen);
  const setIsOpen = useUiStore((state) => state.setIsEditorSearchOpen);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 10);
    } else {
      setQuery("");
      window.getSelection()?.removeAllRanges();
    }
  }, [isOpen]);

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
    inputRef,
    findNext: () => find(false),
    findPrev: () => find(true),
  };
}
