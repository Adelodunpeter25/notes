export type AuthStackParamList = {
  Login: undefined;
  Signup: undefined;
};

export type AppStackParamList = {
  Dashboard: undefined;
  FolderDetails: { folderId: string; folderName: string };
  Editor: { noteId: string };
  Search: undefined;
};
