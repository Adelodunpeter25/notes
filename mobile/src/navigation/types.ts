import type { Note } from "@shared/notes";

export type AuthStackParamList = {
  Login: undefined;
  Signup: undefined;
};

export type AppStackParamList = {
  Dashboard: undefined;
  FolderDetails: { folderId: string; folderName: string };
  Editor: { noteId: string; note?: Note; isTrash?: boolean };
  Search: { folderId?: string } | undefined;
  Trash: undefined;
  Settings: undefined;
};
