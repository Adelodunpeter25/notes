export type Note = {
  id: string;
  userId?: string;
  folderId?: string;
  title: string;
  content: string;
  isPinned: boolean;
  createdAt?: string;
  updatedAt?: string;
  deletedAt?: string;
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
