export type Folder = {
  id: string;
  userId?: string;
  name: string;
  notesCount: number;
  createdAt?: string;
  updatedAt?: string;
  deletedAt?: string;
};

export type CreateFolderPayload = {
  name: string;
};

export type RenameFolderPayload = {
  name: string;
};
