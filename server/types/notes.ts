export type Note = {
  id: string;
  userId: string;
  folderId?: string | null;
  title: string;
  content: string;
  isPinned: boolean;
  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
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
