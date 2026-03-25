export type Folder = {
  id: string;
  userId: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
};

export type CreateFolderPayload = {
  name: string;
};

export type UpdateFolderPayload = {
  name: string;
};
