import { create } from "zustand";

type KeyboardShortcutsState = {
  onNewNote: (() => void) | null;
  setNewNoteHandler: (handler: (() => void) | null) => void;
  triggerNewNote: () => void;
};

export const useKeyboardShortcutsStore = create<KeyboardShortcutsState>((set, get) => ({
  onNewNote: null,
  setNewNoteHandler: (handler) => set({ onNewNote: handler }),
  triggerNewNote: () => {
    get().onNewNote?.();
  },
}));

