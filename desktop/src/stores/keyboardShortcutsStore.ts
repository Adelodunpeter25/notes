import { create } from "zustand";

type KeyboardShortcutsState = {
  onNewNote: (() => void) | null;
  onNewFolder: (() => void) | null;
  setNewNoteHandler: (handler: (() => void) | null) => void;
  setNewFolderHandler: (handler: (() => void) | null) => void;
  triggerNewNote: () => void;
  triggerNewFolder: () => void;
};

export const useKeyboardShortcutsStore = create<KeyboardShortcutsState>((set, get) => ({
  onNewNote: null,
  onNewFolder: null,
  setNewNoteHandler: (handler) => set({ onNewNote: handler }),
  setNewFolderHandler: (handler) => set({ onNewFolder: handler }),
  triggerNewNote: () => {
    get().onNewNote?.();
  },
  triggerNewFolder: () => {
    get().onNewFolder?.();
  },
}));
