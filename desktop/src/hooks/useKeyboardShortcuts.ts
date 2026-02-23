import { useEffect } from "react";

import { useKeyboardShortcutsStore } from "@/stores";

export function useKeyboardShortcuts() {
  const triggerNewNote = useKeyboardShortcutsStore((state) => state.triggerNewNote);
  const triggerNewFolder = useKeyboardShortcutsStore((state) => state.triggerNewFolder);

  useEffect(() => {
    function handleKeydown(event: KeyboardEvent) {
      const hasMetaOrCtrl = event.metaKey || event.ctrlKey;
      const isNewNoteShortcut =
        hasMetaOrCtrl &&
        !event.shiftKey &&
        event.key.toLowerCase() === "n";
      const isNewFolderShortcut =
        hasMetaOrCtrl &&
        event.shiftKey &&
        event.key.toLowerCase() === "n";

      if (isNewFolderShortcut) {
        event.preventDefault();
        triggerNewFolder();
        return;
      }

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
  }, [triggerNewFolder, triggerNewNote]);
}
