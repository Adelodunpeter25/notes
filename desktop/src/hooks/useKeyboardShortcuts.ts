import { useEffect } from "react";

import { useKeyboardShortcutsStore } from "@/stores";

export function useKeyboardShortcuts() {
  const triggerNewNote = useKeyboardShortcutsStore((state) => state.triggerNewNote);

  useEffect(() => {
    function handleKeydown(event: KeyboardEvent) {
      const isNewNoteShortcut =
        (event.metaKey || event.ctrlKey) &&
        event.key.toLowerCase() === "n";

      if (!isNewNoteShortcut) {
        return;
      }

      event.preventDefault();
      triggerNewNote();
    }

    window.addEventListener("keydown", handleKeydown);
    return () => {
      window.removeEventListener("keydown", handleKeydown);
    };
  }, [triggerNewNote]);
}

