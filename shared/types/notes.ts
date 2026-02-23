export type Note = {
  id: string;
  folderId?: string;
  title: string;
  content: string;
  isPinned: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type ListNotesParams = {
  folderId?: string;
  q?: string;
};

export type CreateNotePayload = {
  folderId?: string;
  title: string;
  content: string;
  isPinned?: boolean;
};

export type UpdateNotePayload = {
  folderId?: string;
  title?: string;
  content?: string;
  isPinned?: boolean;
};
