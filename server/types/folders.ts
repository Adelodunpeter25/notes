export type Folder = {
  id: string;
  userId: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
};

export type CreateFolderPayload = {
  name: string;
};

export type UpdateFolderPayload = {
  name: string;
};
