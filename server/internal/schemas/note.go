package schemas

import "time"

type CreateNoteRequest struct {
	FolderID *string `json:"folderId"`
	Title    string  `json:"title"`
	Content  string  `json:"content"`
	IsPinned bool    `json:"isPinned"`
}

type UpdateNoteRequest struct {
	FolderID *string `json:"folderId"`
	Title    *string `json:"title"`
	Content  *string `json:"content"`
	IsPinned *bool   `json:"isPinned"`
}

type NoteResponse struct {
	ID        string    `json:"id"`
	FolderID  *string   `json:"folderId,omitempty"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	IsPinned  bool      `json:"isPinned"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}
