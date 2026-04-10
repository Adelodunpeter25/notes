import { useEffect } from "react";

import { useKeyboardShortcutsStore } from "@/stores";
import { useUiStore } from "@/stores/uiStore";

export function useKeyboardShortcuts() {
  const triggerNewNote = useKeyboardShortcutsStore((state) => state.triggerNewNote);
  const triggerNewFolder = useKeyboardShortcutsStore((state) => state.triggerNewFolder);
  const setActiveView = useUiStore((state) => state.setActiveView);
  const setIsSearchExpanded = useUiStore((state) => state.setIsSearchExpanded);
  const setIsSearchModalOpen = useUiStore((state) => state.setIsSearchModalOpen);
  const setIsEditorSearchOpen = useUiStore((state) => state.setIsEditorSearchOpen);
  const selectedNoteId = useUiStore((state) => state.selectedNoteId);

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
      const isNotesViewShortcut =
        hasMetaOrCtrl &&
        !event.shiftKey &&
        event.key === "1";
      const isTasksViewShortcut =
        hasMetaOrCtrl &&
        !event.shiftKey &&
        event.key === "2";
      const isSearchShortcut =
        hasMetaOrCtrl &&
        !event.shiftKey &&
        event.key.toLowerCase() === "f";

      if (isNewFolderShortcut) {
        event.preventDefault();
        triggerNewFolder();
        return;
      }

      if (isNotesViewShortcut) {
        event.preventDefault();
        setActiveView("notes");
        return;
      }

      if (isTasksViewShortcut) {
        event.preventDefault();
        setActiveView("tasks");
        return;
      }

      if (isSearchShortcut) {
        event.preventDefault();
        if (selectedNoteId) {
          setIsEditorSearchOpen(true);
        } else {
          setIsSearchModalOpen(true);
        }
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
  }, [setActiveView, setIsSearchExpanded, setIsEditorSearchOpen, setIsSearchModalOpen, selectedNoteId, triggerNewFolder, triggerNewNote]);
}
