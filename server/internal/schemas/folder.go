package schemas

type CreateFolderRequest struct {
	Name string `json:"name"`
}

type UpdateFolderRequest struct {
	Name string `json:"name"`
}

type FolderResponse struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	NotesCount int64  `json:"notesCount"`
}
