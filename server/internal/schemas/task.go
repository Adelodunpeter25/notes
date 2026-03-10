package schemas

import "time"

type CreateTaskRequest struct {
	Title       string     `json:"title"`
	Description string     `json:"description"`
	IsCompleted bool       `json:"isCompleted"`
	DueDate     *time.Time `json:"dueDate"`
}

type UpdateTaskRequest struct {
	Title       *string    `json:"title"`
	Description *string    `json:"description"`
	IsCompleted *bool      `json:"isCompleted"`
	DueDate     *time.Time `json:"dueDate"`
}

type TaskResponse struct {
	ID          string     `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	IsCompleted bool       `json:"isCompleted"`
	DueDate     *time.Time `json:"dueDate"`
	CreatedAt   time.Time  `json:"createdAt"`
	UpdatedAt   time.Time  `json:"updatedAt"`
}
