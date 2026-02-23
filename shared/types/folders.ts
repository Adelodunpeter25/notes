export type Folder = {
  id: string;
  name: string;
  notesCount: number;
};

export type CreateFolderPayload = {
  name: string;
};

export type RenameFolderPayload = {
  name: string;
};
